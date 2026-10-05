import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import 'explain_back_gateway.dart';

/// Client-safe adapter over LA-0026's server-owned attempt boundary.
///
/// Opening an attempt persists only response digest/length. Until a separately
/// authorized server evaluator completes the attempt, this returns unavailable
/// and never converts the learner's text into a mastery claim on-device.
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
      final responseDigest = sha256.convert(utf8.encode(normalized)).toString();

      await client.rpc<Object?>(
        'open_explain_back_attempt',
        params: {
          'p_attempt_id': request.attemptId.value,
          'p_material_id': request.materialId.value,
          'p_source_content_hash': request.sourceContentDigest,
          'p_response_digest': responseDigest,
          'p_response_length': normalized.length,
        },
      );

      final rows = await client.rpc<List<dynamic>>(
        'read_explain_back_attempt',
        params: {'p_attempt_id': request.attemptId.value},
      );
      if (rows.isEmpty) {
        return const ExplainBackUnavailable('Değerlendirme kaydı doğrulanamadı.');
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      final digest = row['source_content_hash'] as String? ?? '';
      if (digest != request.sourceContentDigest) {
        return const ExplainBackUnavailable('Kaynak değişti; eski denemeyi öğrenme kanıtı saymıyoruz.');
      }

      final rawKind = row['evaluation_kind'] as String?;
      final evaluatorRef = row['evaluator_ref'] as String?;
      if (rawKind == null || evaluatorRef == null || evaluatorRef.trim().isEmpty) {
        return const ExplainBackUnavailable(
          'Yanıt kaydedildi ancak güvenilir anlamsal değerlendirme henüz tamamlanmadı.',
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
        sourceContentDigest: digest,
        kind: kind,
        feedback: (row['feedback'] as String?)?.trim() ?? '',
        targetedRepair: (row['targeted_repair'] as String?)?.trim() ?? '',
        executionRef: evaluatorRef,
      );
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
