import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../generation/supabase_source_summary_gateway.dart';
import '../learning/explain_back_gateway.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'companion_view.dart';

class ExplainBackScreen extends StatefulWidget {
  const ExplainBackScreen({
    required this.runtime,
    required this.source,
    this.sourceGateway = const SupabaseSourceSummaryGateway(),
    super.key,
  });

  final AppRuntime runtime;
  final SourceVersionRecord source;
  final SupabaseSourceSummaryGateway sourceGateway;

  @override
  State<ExplainBackScreen> createState() => _ExplainBackScreenState();
}

class _ExplainBackScreenState extends State<ExplainBackScreen> {
  SupabaseSourceSummaryGateway get _sourceGateway => widget.sourceGateway;

  final _controller = TextEditingController();
  ExplainBackResult? _result;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final response = _controller.text.trim();
    if (response.isEmpty || _submitting) return;
    setState(() => _submitting = true);

    ExplainBackResult result;
    try {
      final currentSource = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: widget.source.identity.materialId,
      );
      if (currentSource == null ||
          currentSource.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
          currentSource.identity.contentDigest != widget.source.identity.contentDigest) {
        result = const ExplainBackUnavailable('Kaynak değişti; güncel kaynakla yeniden dene.');
      } else {
        final material = await widget.runtime.store.material(
          learner: widget.runtime.learner,
          materialId: widget.source.identity.materialId,
        );
        final extracted = await widget.runtime.store.extractedContentForSource(
          learner: widget.runtime.learner,
          sourceVersionId: widget.source.identity.sourceVersionId,
        );
        if (material == null ||
            extracted == null ||
            !extracted.isValid ||
            extracted.sourceContentDigest != widget.source.identity.contentDigest) {
          result = const ExplainBackUnavailable('Güncel kaynak değerlendirilemedi.');
        } else {
          final normalizedSource = extracted.normalizedText.trim();
          final groundingContentHash = sha256.convert(utf8.encode(normalizedSource)).toString();

          var serverMaterialId = await widget.runtime.store.summaryServerMaterialId(
            learner: widget.runtime.learner,
            materialId: widget.source.identity.materialId,
            sourceVersionId: widget.source.identity.sourceVersionId,
          );

          if (serverMaterialId == null) {
            final staleServerMaterialId = await widget.runtime.store.summaryServerMaterialId(
              learner: widget.runtime.learner,
              materialId: widget.source.identity.materialId,
            );
            if (staleServerMaterialId != null) {
              final removed = await _sourceGateway.deleteServerMaterial(staleServerMaterialId);
              if (!removed) {
                result = const ExplainBackUnavailable('Önceki kaynak kopyası güvenli biçimde temizlenemedi.');
                if (mounted) {
                  setState(() {
                    _submitting = false;
                    _result = result;
                  });
                }
                return;
              }
              await widget.runtime.store.clearSummaryJob(
                learner: widget.runtime.learner,
                materialId: widget.source.identity.materialId,
              );
            }

            serverMaterialId = await _sourceGateway.ensureServerMaterial(
              source: SourceIngestResult(
                material: material,
                sourceVersion: currentSource,
                extractedContent: extracted,
              ),
            );

            final sourceAfterBinding = await widget.runtime.store.currentSourceVersion(
              learner: widget.runtime.learner,
              materialId: widget.source.identity.materialId,
            );
            if (sourceAfterBinding?.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
                sourceAfterBinding?.identity.contentDigest != widget.source.identity.contentDigest) {
              await _sourceGateway.deleteServerMaterial(serverMaterialId);
              result = const ExplainBackUnavailable('Kaynak değişti; eski sürümü değerlendirmiyoruz.');
              if (mounted) {
                setState(() {
                  _submitting = false;
                  _result = result;
                });
              }
              return;
            }

            await widget.runtime.store.saveServerMaterialBinding(
              learner: widget.runtime.learner,
              materialId: widget.source.identity.materialId,
              sourceVersionId: widget.source.identity.sourceVersionId,
              serverMaterialId: serverMaterialId,
            );
          }

          final attemptDigest = sha256
              .convert(
                utf8.encode(
                  jsonEncode([
                    widget.runtime.learner.id.value,
                    widget.source.identity.sourceVersionId.value,
                    response,
                  ]),
                ),
              )
              .toString();

          result = await widget.runtime.explainBack.evaluate(
            ExplainBackRequest(
              attemptId: ExplainBackAttemptId('explain-${attemptDigest.substring(0, 32)}'),
              materialId: MaterialId(serverMaterialId),
              sourceVersionId: widget.source.identity.sourceVersionId,
              sourceContentDigest: widget.source.identity.contentDigest,
              groundingContentHash: groundingContentHash,
              response: response,
              outputLocale: 'tr-TR',
            ),
          );
        }
      }
    } catch (_) {
      result = const ExplainBackUnavailable('Değerlendirme servisine şu anda ulaşılamıyor.');
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = result is ExplainBackEvaluated && !result.matches(widget.source.identity)
          ? const ExplainBackUnavailable('Kaynak değiştiği için bu değerlendirmeyi öğrenme kanıtı saymıyoruz.')
          : result;
    });
  }

  void _retry() => setState(() {
    _result = null;
    _controller.clear();
  });

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Kendi cümlelerinle anlat')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: CompanionView(state: CompanionVisualState.listen, size: 54),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppPalette.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          child: Text(
                            'KAYNAĞA BAKMADAN',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppPalette.primary, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Anladığını kendi cümlelerinle açıkla.',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(color: AppPalette.signalSoft, borderRadius: BorderRadius.circular(14)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                child: Text('Bu aktif deneme değerlendirilmeden öğrenme kanıtı veya ustalık iddiası oluşturmaz.'),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              enabled: !_submitting && result == null,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Örneğin: Bu konunun temel fikri...',
              ),
            ),
            const SizedBox(height: 10),
            if (result == null)
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Değerlendiriliyor…' : 'Anlatımımı değerlendir'),
              ),
            if (result is ExplainBackUnavailable) _UnavailableResult(reason: result.reason, onRetry: _retry),
            if (result is ExplainBackEvaluated) _EvaluatedResult(result: result, onRetry: _retry),
          ],
        ),
      ),
    );
  }
}

class _UnavailableResult extends StatelessWidget {
  const _UnavailableResult({required this.reason, required this.onRetry});
  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: AppPalette.attentionSoft, borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppPalette.attention, size: 20),
              SizedBox(width: 9),
              CompanionView(state: CompanionVisualState.correct, size: 42),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Henüz güvenilir değerlendirme yok',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(reason),
          const SizedBox(height: 8),
          const Text('Yanıtını doğru/yanlış diye tahmin etmiyoruz ve bunu öğrenme kanıtı olarak kaydetmiyoruz.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Yeniden dene')),
        ],
      ),
    ),
  );
}

class _EvaluatedResult extends StatelessWidget {
  const _EvaluatedResult({required this.result, required this.onRetry});
  final ExplainBackEvaluated result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (result.kind) {
      ExplainBackEvaluationKind.sufficient => 'Anlatımında temel fikirler görünüyor',
      ExplainBackEvaluationKind.gapDetected => 'Bir noktayı güçlendirebiliriz',
      ExplainBackEvaluationKind.notEvaluable => 'Bu yanıttan güvenilir sonuç çıkaramıyoruz',
      ExplainBackEvaluationKind.unavailable => 'Değerlendirme kullanılamıyor',
    };
    final isStrong = result.kind == ExplainBackEvaluationKind.sufficient;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isStrong ? AppPalette.successSoft : AppPalette.attentionSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanionView(state: isStrong ? CompanionVisualState.success : CompanionVisualState.correct, size: 48),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(result.feedback),
            if (result.targetedRepair.isNotEmpty) ...[
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hedefli düzeltme', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(result.targetedRepair),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Tekrar kendi cümlelerimle anlat')),
          ],
        ),
      ),
    );
  }
}
