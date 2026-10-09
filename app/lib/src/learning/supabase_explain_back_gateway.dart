import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import 'explain_back_gateway.dart';

/// Authenticated adapter over the source-bound Explain-back evaluator.
///
/// Learner response plaintext is sent only for the live evaluator request. The
/// database stores only response digest/length plus the bounded evaluation.
class SupabaseExplainBackGateway implements ExplainBackGateway {
  const SupabaseExplainBackGateway();

  @override
  Future<ExplainBackResult> evaluate(ExplainBackRequest request) async {
    final normalized = request.response.trim();
    if (normalized.isEmpty || normalized.length > 2000) {
      return const ExplainBackUnavailable('Yanıt boş veya desteklenen sınırın dışında.');
    }

    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      if (client.auth.currentSession == null) {
        return const ExplainBackUnavailable('Değerlendirme için güvenli oturum gerekli.');
      }

      final invocation = await client.functions.invoke(
        'explain-back-evaluator',
        body: {
          'attempt_id': request.attemptId.value,
          'material_id': request.materialId.value,
          'source_content_hash': request.groundingContentHash,
          'response': normalized,
          'output_locale': request.outputLocale,
        },
      );
      final data = invocation.data;
      final evaluatorStatus = data is Map ? data['status'] as String? : null;

      if (evaluatorStatus == 'reconciliation_required') {
        return const ExplainBackUnavailable(
          'Önceki değerlendirme çağrısının sonucu belirsiz. Çifte değerlendirme yapmamak için otomatik tekrar kapalı.',
        );
      }
      if (evaluatorStatus == 'failed_final') {
        return const ExplainBackUnavailable('Bu yanıt güvenilir biçimde değerlendirilemedi.');
      }
      if (evaluatorStatus == 'failed_retryable' || evaluatorStatus == 'not_runnable') {
        return const ExplainBackUnavailable('Değerlendirme geçici olarak tamamlanamadı. Yeniden deneyebilirsin.');
      }

      List<dynamic> rows = <dynamic>[];
      for (var attempt = 0; attempt < 4; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
        rows = await client.rpc<List<dynamic>>(
          'read_explain_back_attempt',
          params: {'p_attempt_id': request.attemptId.value},
        );
        if (rows.isNotEmpty) {
          final current = Map<String, dynamic>.from(rows.first as Map);
          if (current['evaluation_kind'] != null) break;
        }
      }
      if (rows.isEmpty) {
        return const ExplainBackUnavailable('Değerlendirme kaydı doğrulanamadı.');
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      final groundingHash = row['source_content_hash'] as String? ?? '';
      if (groundingHash != request.groundingContentHash) {
        return const ExplainBackUnavailable('Kaynak değişti; eski denemeyi öğrenme kanıtı saymıyoruz.');
      }

      final rawKind = row['evaluation_kind'] as String?;
      final evaluatorRef = row['evaluator_ref'] as String?;
      if (rawKind == null || evaluatorRef == null || evaluatorRef.trim().isEmpty) {
        return const ExplainBackUnavailable(
          'Yanıt güvenilir biçimde değerlendirilmeden öğrenme kanıtı oluşturmuyoruz.',
        );
      }

      final kind = switch (rawKind) {
        'sufficient' => ExplainBackEvaluationKind.sufficient,
        'gap_detected' => ExplainBackEvaluationKind.gapDetected,
        'not_evaluable' => ExplainBackEvaluationKind.notEvaluable,
        _ => ExplainBackEvaluationKind.unavailable,
      };
      return ExplainBackEvaluated(
        attemptId: request.attemptId,
        sourceVersionId: request.sourceVersionId,
        sourceContentDigest: request.sourceContentDigest,
        kind: kind,
        feedback: (row['feedback'] as String?)?.trim() ?? '',
        targetedRepair: (row['targeted_repair'] as String?)?.trim() ?? '',
        executionRef: evaluatorRef,
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final functionStatus = details is Map ? details['status'] as String? : null;
      if (error.status == 429 || functionStatus == 'quota_exceeded') {
        return const ExplainBackUnavailable(
          'Bugünkü anlatım değerlendirme limitine ulaştın. Yeni değerlendirmeler günlük limit yenilendiğinde açılır.',
        );
      }
      if (functionStatus == 'evaluator_not_configured') {
        return const ExplainBackUnavailable(
          'Anlatım değerlendirme servisi henüz etkin değil. Yanıtını öğrenme kanıtı olarak kaydetmiyoruz.',
        );
      }
      if (functionStatus == 'stale_source') {
        return const ExplainBackUnavailable('Kaynak değişti; güncel kaynakla yeniden dene.');
      }
      if (functionStatus == 'source_unavailable') {
        return const ExplainBackUnavailable('Güncel kaynak kullanılamıyor.');
      }
      if (functionStatus == 'attempt_id_reused') {
        return const ExplainBackUnavailable('Bu deneme kimliği farklı bir yanıtla yeniden kullanılamaz.');
      }
      return const ExplainBackUnavailable('Değerlendirme servisine şu anda ulaşılamıyor.');
    } on PostgrestException catch (error) {
      if (error.message.contains('stale_source')) {
        return const ExplainBackUnavailable('Kaynak değişti; güncel kaynakla yeniden dene.');
      }
      if (error.message.contains('material_not_found') || error.message.contains('source_unavailable')) {
        return const ExplainBackUnavailable('Güncel kaynak kullanılamıyor.');
      }
      if (error.message.contains('attempt_id_reused')) {
        return const ExplainBackUnavailable('Bu deneme kimliği farklı bir yanıtla yeniden kullanılamaz.');
      }
      return const ExplainBackUnavailable('Değerlendirme servisine şu anda ulaşılamıyor.');
    } catch (_) {
      return const ExplainBackUnavailable('Değerlendirme servisine şu anda ulaşılamıyor.');
    }
  }
}
