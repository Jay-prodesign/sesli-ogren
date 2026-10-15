import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../account/entitlement_access_gateway.dart';
import '../generation/supabase_source_summary_gateway.dart';
import '../learning/explain_back_gateway.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';
import 'entitlement_access_card.dart';
import 'la0040_visual_treatments.dart';
import 'learning_slice_screen.dart';
import 'living_study_desk_home.dart';

Widget _preserveExplainBackExperience(BuildContext context, Widget screen) {
  final treatment = LearningVisualTreatmentScope.maybeOf(context);
  if (treatment != null) return LearningVisualTreatmentScope(treatment: treatment, child: screen);
  return LivingDeskReviewScope.active(context) ? LivingDeskReviewScope(child: screen) : screen;
}

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
  EntitlementAccess? _access;
  bool _submitting = false;
  bool _sourceChanged = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _admitExplainBackEvaluation() async {
    if (!widget.runtime.learner.isAuthenticated ||
        widget.runtime.entitlementAccess is UnavailableEntitlementAccessGateway) {
      return true;
    }
    final access = await widget.runtime.entitlementAccess.check(
      learner: widget.runtime.learner,
      capability: EntitlementCapability.explainBack,
    );
    if (!mounted) return false;
    if (!access.isAllowed) {
      setState(() => _access = access);
      return false;
    }
    if (_access != null) {
      setState(() => _access = null);
    }
    return true;
  }

  Future<EntitlementAccess?> _blockedExplainBackAccessAfterFailure() async {
    if (!widget.runtime.learner.isAuthenticated ||
        widget.runtime.entitlementAccess is UnavailableEntitlementAccessGateway) {
      return null;
    }
    final access = await widget.runtime.entitlementAccess.check(
      learner: widget.runtime.learner,
      capability: EntitlementCapability.explainBack,
    );
    return access.isAllowed ? null : access;
  }

  void _retryEntitlement() {
    if (_submitting) return;
    setState(() => _access = null);
    _submit();
  }

  Future<void> _submit() async {
    final response = _controller.text.trim();
    if (response.isEmpty || _submitting) return;
    setState(() => _submitting = true);

    if (!await _admitExplainBackEvaluation()) {
      if (mounted) setState(() => _submitting = false);
      return;
    }

    if (widget.runtime.explainBack is UnavailableExplainBackGateway) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = const ExplainBackUnavailable('Güvenilir anlamsal değerlendirme servisi henüz etkin değil.');
      });
      return;
    }

    ExplainBackResult result;
    var sourceChanged = false;
    try {
      final currentSource = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: widget.source.identity.materialId,
      );
      if (currentSource == null ||
          currentSource.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
          currentSource.identity.contentDigest != widget.source.identity.contentDigest) {
        sourceChanged = true;
        result = const ExplainBackUnavailable(
          'Kaynak değişti; eski sürüme bağlı değerlendirmeyi yeniden göndermiyoruz.',
        );
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
              await widget.runtime.store.clearServerMaterialBinding(
                learner: widget.runtime.learner,
                materialId: widget.source.identity.materialId,
              );
            }

            serverMaterialId = await _sourceGateway.ensureServerMaterial(
              source: SourceIngestResult(material: material, sourceVersion: currentSource, extractedContent: extracted),
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
                  jsonEncode([widget.runtime.learner.id.value, widget.source.identity.sourceVersionId.value, response]),
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

          final sourceAfterEvaluation = await widget.runtime.store.currentSourceVersion(
            learner: widget.runtime.learner,
            materialId: widget.source.identity.materialId,
          );
          if (sourceAfterEvaluation?.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
              sourceAfterEvaluation?.identity.contentDigest != widget.source.identity.contentDigest) {
            sourceChanged = true;
            result = const ExplainBackUnavailable(
              'Kaynak değerlendirme sırasında değişti. Eski sürüme ait sonucu göstermiyoruz.',
            );
          }
        }
      }
    } catch (_) {
      result = const ExplainBackUnavailable('Değerlendirme servisine şu anda ulaşılamıyor.');
    }

    if (result is ExplainBackUnavailable && !sourceChanged) {
      final blockedAccess = await _blockedExplainBackAccessAfterFailure();
      if (blockedAccess != null) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _access = blockedAccess;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _sourceChanged = sourceChanged;
      _result = result is ExplainBackEvaluated && !result.matches(widget.source.identity)
          ? const ExplainBackUnavailable('Kaynak değiştiği için bu değerlendirmeyi öğrenme kanıtı saymıyoruz.')
          : result;
    });
  }

  void _retryUnavailable() {
    if (_sourceChanged) return;
    setState(() {
      _access = null;
      _result = null;
    });
  }

  void _startFreshAttempt() => setState(() {
    _sourceChanged = false;
    _result = null;
    _controller.clear();
  });

  Future<void> _openRecall() async {
    final sourceUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _preserveExplainBackExperience(
          context,
          LearningSliceScreen(runtime: widget.runtime, materialId: widget.source.identity.materialId),
        ),
      ),
    );
    if (sourceUpdated == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _backToMaterial() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final living = LivingDeskReviewScope.active(context);
    final truthSoft = living ? AtelierStyle.pulseSoft : AppPalette.signalSoft;
    return Scaffold(
      backgroundColor: living ? AtelierStyle.canvas : null,
      appBar: AppBar(
        title: const Text('Kendi cümlelerinle anlat'),
        backgroundColor: living ? AtelierStyle.canvas : null,
        foregroundColor: living ? AtelierStyle.ink : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AtelierStyle.focus,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Color(0x1A14224A), blurRadius: 24, offset: Offset(0, 12))],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                          Text(
                            'KAYNAĞA BAKMADAN',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AtelierStyle.mark, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Anladığını kendi cümlelerinle açıkla.',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            KeyedSubtree(
              key: const ValueKey('explain-back-source-trust'),
              child: AtelierSourceTrustStrip(sourceVersion: widget.source),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(color: truthSoft, borderRadius: BorderRadius.circular(14)),
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
            if (_access != null) ...[
              EntitlementAccessCard(
                access: _access!,
                onRetry: _retryEntitlement,
                onReturnToStudy: _backToMaterial,
              ),
            ] else if (result == null)
              FilledButton(
                style: living
                    ? FilledButton.styleFrom(backgroundColor: AtelierStyle.teal, foregroundColor: Colors.white)
                    : null,
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Değerlendiriliyor…' : 'Anlatımımı değerlendir'),
              ),
            if (result is ExplainBackUnavailable)
              _UnavailableResult(
                reason: result.reason,
                sourceChanged: _sourceChanged,
                onRetry: _retryUnavailable,
                onRecall: _openRecall,
                onBack: _backToMaterial,
              ),
            if (result is ExplainBackEvaluated)
              _EvaluatedResult(
                result: result,
                onRetry: _startFreshAttempt,
                onRecall: _openRecall,
                onBack: _backToMaterial,
              ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableResult extends StatelessWidget {
  const _UnavailableResult({
    required this.reason,
    required this.sourceChanged,
    required this.onRetry,
    required this.onRecall,
    required this.onBack,
  });

  final String reason;
  final bool sourceChanged;
  final VoidCallback onRetry;
  final VoidCallback onRecall;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: LivingDeskReviewScope.active(context) ? AtelierStyle.attentionSoft : AppPalette.attentionSoft,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: LivingDeskReviewScope.active(context) ? AtelierStyle.attention : null,
              ),
              const SizedBox(width: 8),
              const CompanionView(state: CompanionVisualState.think, size: 42),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sourceChanged ? 'Kaynak değişti' : 'Henüz güvenilir değerlendirme yok',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(reason),
          const SizedBox(height: 8),
          Text(
            sourceChanged
                ? 'Eski kaynak sürümüne göre sonuç göstermiyoruz ve yanıtını öğrenme kanıtı olarak kaydetmiyoruz.'
                : 'Yanıtını doğru/yanlış diye tahmin etmiyoruz ve bunu öğrenme kanıtı olarak kaydetmiyoruz.',
          ),
          const SizedBox(height: 12),
          if (!sourceChanged) ...[
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Aynı yanıtla yeniden dene'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: onRecall,
            icon: const Icon(Icons.psychology_alt_outlined),
            label: Text(sourceChanged ? 'Güncel kaynakla Hatırla' : 'Hatırla ile devam et'),
          ),
          TextButton(onPressed: onBack, child: Text(sourceChanged ? 'Güncel çalışmaya dön' : 'Önceki çalışmaya dön')),
        ],
      ),
    ),
  );
}

class _EvaluatedResult extends StatelessWidget {
  const _EvaluatedResult({required this.result, required this.onRetry, required this.onRecall, required this.onBack});

  final ExplainBackEvaluated result;
  final VoidCallback onRetry;
  final VoidCallback onRecall;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final living = LivingDeskReviewScope.active(context);
    final title = switch (result.kind) {
      ExplainBackEvaluationKind.sufficient => 'Anlatımında temel fikirler görünüyor',
      ExplainBackEvaluationKind.gapDetected => 'Bir noktayı güçlendirebiliriz',
      ExplainBackEvaluationKind.notEvaluable => 'Bu yanıttan güvenilir sonuç çıkaramıyoruz',
      ExplainBackEvaluationKind.unavailable => 'Değerlendirme kullanılamıyor',
    };
    final companionState = switch (result.kind) {
      ExplainBackEvaluationKind.sufficient => CompanionVisualState.success,
      ExplainBackEvaluationKind.gapDetected => CompanionVisualState.correct,
      ExplainBackEvaluationKind.notEvaluable || ExplainBackEvaluationKind.unavailable => CompanionVisualState.think,
    };
    final recallLabel = switch (result.kind) {
      ExplainBackEvaluationKind.sufficient => 'Hatırla ile pekiştir',
      ExplainBackEvaluationKind.gapDetected => 'Hatırla ile kontrol et',
      ExplainBackEvaluationKind.notEvaluable || ExplainBackEvaluationKind.unavailable => 'Hatırla ile devam et',
    };
    final isStrong = result.kind == ExplainBackEvaluationKind.sufficient;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isStrong
            ? (living ? AtelierStyle.mint : AppPalette.successSoft)
            : (living ? AtelierStyle.attentionSoft : AppPalette.attentionSoft),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanionView(state: companionState, size: 48),
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
                  color: (living ? AtelierStyle.paper : AppPalette.surface).withValues(alpha: 0.82),
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
            Text(
              'Bu geri bildirim açıklamana dayanır; bağımsız Hatırla kanıtının yerini tutmaz.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRecall,
              icon: const Icon(Icons.psychology_alt_outlined),
              label: Text(recallLabel),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar kendi cümlelerimle anlat'),
            ),
            TextButton(onPressed: onBack, child: const Text('Önceki çalışmaya dön')),
          ],
        ),
      ),
    );
  }
}
