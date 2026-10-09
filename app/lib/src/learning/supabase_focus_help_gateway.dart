import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_learner_auth.dart';
import 'focus_help_gateway.dart';

/// Production Focus adapter over the same durable generation authority used by
/// Summary/Explain. The Flutter client supplies only authenticated source/job
/// identity plus the learner's bounded question; provider credentials stay in
/// the Edge Function.
class SupabaseFocusHelpGateway implements FocusHelpGateway {
  const SupabaseFocusHelpGateway();

  @override
  Future<FocusHelpResult> help(FocusHelpRequest request) async {
    final question = request.learnerQuestion?.trim() ?? '';
    final serverMaterialId = request.serverMaterialId;
    final groundingContentHash = request.groundingContentHash;
    if (question.length < 2 || question.length > 600) {
      return const FocusHelpUnavailable('Sorunu 2–600 karakter arasında kısa ve somut biçimde yaz.');
    }
    if (serverMaterialId == null ||
        groundingContentHash == null ||
        !_isUuid(serverMaterialId)) {
      return const FocusHelpUnavailable('Güncel kaynak sunucuda güvenli biçimde bağlanamadı.');
    }

    try {
      final client = await SupabaseLearnerAuth.clientForAuthenticatedRuntime();
      if (client.auth.currentSession == null) {
        return const FocusHelpUnavailable('Odak yardımı için güvenli oturum gerekli.');
      }

      final serverKind = switch (request.kind) {
        FocusHelpKind.hint => 'hint',
        FocusHelpKind.directExplanation => 'direct_explanation',
      };
      final digest = sha256.convert(utf8.encode(question)).toString();
      final jobId = await client.rpc<String>(
        'request_focus_help',
        params: {
          'p_material_id': serverMaterialId,
          'p_source_content_hash': groundingContentHash,
          'p_question': question,
          'p_help_kind': serverKind,
          'p_idempotency_key':
              'focus:$serverMaterialId:$serverKind:${digest.substring(0, 24)}',
        },
      );

      final jobs = await client
          .from('generation_jobs')
          .select('state,failure_class')
          .eq('id', jobId)
          .limit(1);
      if (jobs.isEmpty) {
        return const FocusHelpUnavailable('Odak yardımı işi doğrulanamadı.');
      }

      final state = jobs.first['state'] as String;
      final failureClass = jobs.first['failure_class'] as String?;
      if (failureClass == 'reconciliation_required') {
        return const FocusHelpUnavailable(
          'Önceki model çağrısının sonucu belirsiz. Güvenli uzlaştırma olmadan aynı çağrıyı tekrarlamıyoruz.',
        );
      }
      if (state == 'FAILED_FINAL' || state == 'CANCELLED') {
        return const FocusHelpUnavailable('Bu odak yardımı tamamlanamadı. Sorunu değiştirip yeniden deneyebilirsin.');
      }
      if (state == 'FAILED_RETRYABLE') {
        await client.rpc<String>('retry_generation_job', params: {'p_job_id': jobId});
      }
      if (state == 'QUEUED' || state == 'PROCESSING' || state == 'FAILED_RETRYABLE') {
        final response = await client.functions.invoke(
          'generation-worker',
          body: {'job_id': jobId},
        );
        if (response.status < 200 || response.status >= 300) {
          return const FocusHelpUnavailable('Kaynağa bağlı AI yardımı şu anda başlatılamadı.');
        }
      }

      List<dynamic> rows = const <dynamic>[];
      for (var attempt = 0; attempt < 6; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        rows = await client.rpc<List<dynamic>>(
          'read_focus_help',
          params: {
            'p_job_id': jobId,
            'p_source_content_hash': groundingContentHash,
          },
        );
        if (rows.isNotEmpty) break;
      }
      if (rows.isEmpty) {
        return const FocusHelpUnavailable('Yanıt henüz hazır değil. Biraz sonra yeniden deneyebilirsin.');
      }

      final row = Map<String, dynamic>.from(rows.first as Map);
      final content = Map<String, dynamic>.from(row['content'] as Map);
      final responseText = (content['response'] as String?)?.trim() ?? '';
      final rawPoints = content['key_points'];
      final sourceCues = rawPoints is List
          ? rawPoints
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .take(8)
              .toList(growable: false)
          : const <String>[];
      final hash = row['source_content_hash'] as String? ?? '';
      if (responseText.isEmpty || sourceCues.isEmpty || hash != groundingContentHash) {
        return const FocusHelpUnavailable('Yanıt güncel kaynakla güvenilir biçimde eşleşmedi.');
      }

      return FocusHelpReady(
        sourceVersionId: request.sourceVersionId,
        sourceContentDigest: request.sourceContentDigest,
        text: responseText,
        sourceCues: sourceCues,
        executionRef: (row['provider_execution_ref'] as String?) ?? 'server:focus-artifact',
      );
    } on PostgrestException catch (error) {
      if (error.message.contains('quota_exceeded')) {
        return const FocusHelpUnavailable('Bugünkü ücretsiz AI yardım hakkın doldu. Kaynak, Dinle ve Hatırla açık kalır.');
      }
      if (error.message.contains('stale_source')) {
        return const FocusHelpUnavailable('Kaynak değişti. Güncel kaynakla yeniden sor.');
      }
      if (error.message.contains('material_not_found') || error.message.contains('job_not_found')) {
        return const FocusHelpUnavailable('Güncel kaynak kullanılamıyor.');
      }
      return const FocusHelpUnavailable('Kaynağa bağlı AI yardımına şu anda ulaşılamıyor.');
    } catch (_) {
      return const FocusHelpUnavailable('Kaynağa bağlı AI yardımına şu anda ulaşılamıyor.');
    }
  }

  static bool _isUuid(String value) =>
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')
          .hasMatch(value);
}
