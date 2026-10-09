import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../generation/grounded_explain_gateway.dart';
import '../generation/supabase_source_summary_gateway.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'explain_back_screen.dart';
import 'learning_slice_screen.dart';

class ExplainScreen extends StatefulWidget {
  const ExplainScreen({
    required this.runtime,
    required this.source,
    this.summaryGateway = const SupabaseSourceSummaryGateway(),
    super.key,
  });

  final AppRuntime runtime;
  final SourceVersionRecord source;
  final SupabaseSourceSummaryGateway summaryGateway;

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  late Future<GroundedExplainResult> _result;

  @override
  void initState() {
    super.initState();
    _result = _request();
  }

  Future<GroundedExplainResult> _request() async {
    if (widget.runtime.explain is UnavailableGroundedExplainGateway) {
      return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.providerNotConfigured);
    }

    try {
      final currentSource = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: widget.source.identity.materialId,
      );
      if (currentSource == null) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.sourceUnavailable);
      }
      if (currentSource.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
          currentSource.identity.contentDigest != widget.source.identity.contentDigest) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.staleSource);
      }

      final extracted = await widget.runtime.store.extractedContentForSource(
        learner: widget.runtime.learner,
        sourceVersionId: widget.source.identity.sourceVersionId,
      );
      if (extracted == null || !extracted.isValid) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.sourceUnavailable);
      }
      if (extracted.sourceContentDigest != widget.source.identity.contentDigest) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.staleSource);
      }
      final groundingContentHash = sha256.convert(utf8.encode(extracted.normalizedText.trim())).toString();

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
          final removed = await widget.summaryGateway.deleteServerMaterial(staleServerMaterialId);
          if (!removed) {
            return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
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

        final material = await widget.runtime.store.material(
          learner: widget.runtime.learner,
          materialId: widget.source.identity.materialId,
        );
        if (material == null) {
          return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.sourceUnavailable);
        }

        final createdServerMaterialId = await widget.summaryGateway.ensureServerMaterial(
          source: SourceIngestResult(material: material, sourceVersion: widget.source, extractedContent: extracted),
        );

        final sourceAfterSubmission = await widget.runtime.store.currentSourceVersion(
          learner: widget.runtime.learner,
          materialId: widget.source.identity.materialId,
        );
        if (sourceAfterSubmission?.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
            sourceAfterSubmission?.identity.contentDigest != widget.source.identity.contentDigest) {
          await widget.summaryGateway.deleteServerMaterial(createdServerMaterialId);
          return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.staleSource);
        }

        await widget.runtime.store.saveServerMaterialBinding(
          learner: widget.runtime.learner,
          materialId: widget.source.identity.materialId,
          sourceVersionId: widget.source.identity.sourceVersionId,
          serverMaterialId: createdServerMaterialId,
        );
        serverMaterialId = createdServerMaterialId;
      }

      final boundServerMaterialId = serverMaterialId;
      if (boundServerMaterialId == null) {
        return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.sourceUnavailable);
      }

      return widget.runtime.explain.explain(
        GroundedExplainRequest(
          materialId: MaterialId(boundServerMaterialId),
          sourceVersionId: widget.source.identity.sourceVersionId,
          sourceContentDigest: widget.source.identity.contentDigest,
          groundingContentHash: groundingContentHash,
          outputLocale: 'tr-TR',
        ),
      );
    } catch (_) {
      return const GroundedExplainUnavailable(reason: GroundedExplainUnavailableReason.temporaryFailure);
    }
  }

  void _retry() => setState(() => _result = _request());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Açıkla')),
    body: SafeArea(
      child: FutureBuilder<GroundedExplainResult>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Unavailable(reason: GroundedExplainUnavailableReason.temporaryFailure, onRetry: _retry);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data!;
          if (result is GroundedExplainReady) {
            if (!result.matches(widget.source.identity)) {
              return _Unavailable(reason: GroundedExplainUnavailableReason.staleSource, onRetry: _retry);
            }
            return _Ready(result: result, runtime: widget.runtime, source: widget.source);
          }
          return _Unavailable(reason: (result as GroundedExplainUnavailable).reason, onRetry: _retry);
        },
      ),
    ),
  );
}

class _Ready extends StatelessWidget {
  const _Ready({required this.result, required this.runtime, required this.source});

  final GroundedExplainReady result;
  final AppRuntime runtime;
  final SourceVersionRecord source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: AppPalette.attentionSoft, borderRadius: BorderRadius.circular(999)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'ÜRETİLMİŞ AÇIKLAMA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppPalette.attention,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            const Spacer(),
            const Icon(Icons.auto_awesome_outlined, color: AppPalette.attention, size: 20),
          ],
        ),
        const SizedBox(height: 14),
        Text('Kaynağına dayalı açıklama', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          source.sourceName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppPalette.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu bölüm kaynak metnin kendisi değil; kaynağına bağlı üretilmiş bir açıklamadır.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.inkMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Text(result.explanation, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
              ],
            ),
          ),
        ),
        if (result.keyPoints.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Önemli noktalar', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final point in result.keyPoints) ...[
            DecoratedBox(
              decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppPalette.primary, size: 18),
                    const SizedBox(width: 9),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(color: AppPalette.signalSoft, borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, color: AppPalette.signal, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Açıklamayı okumak öğrenme kanıtı oluşturmaz. Hazır olduğunda kendi cümlelerinle anlat veya Hatırla ile aktif olarak dene.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(color: AppPalette.primaryDark, borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Şimdi aktif olarak dene',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Okuduğunu kendi cümlelerinle kur veya kaynağa bakmadan hatırla.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.76)),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppPalette.primaryDark),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ExplainBackScreen(runtime: runtime, source: source),
                    ),
                  ),
                  icon: const Icon(Icons.record_voice_over_outlined),
                  label: const Text('Kendi cümlelerinle anlat'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => LearningSliceScreen(runtime: runtime, materialId: source.identity.materialId),
                    ),
                  ),
                  icon: const Icon(Icons.psychology_alt_outlined),
                  label: const Text('Hatırla ile dene'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.reason, required this.onRetry});

  final GroundedExplainUnavailableReason reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, body, retryable) = switch (reason) {
      GroundedExplainUnavailableReason.providerNotConfigured => (
        'Açıklama henüz hazır değil',
        'Kaynağın güvende. Üretilmiş açıklama servisi etkinleştirilmeden burada yapay bir sonuç göstermiyoruz.',
        false,
      ),
      GroundedExplainUnavailableReason.sourceUnavailable => (
        'Kaynak kullanılamıyor',
        'Açıklama yalnızca geçerli kaynak sürümünden üretilebilir.',
        false,
      ),
      GroundedExplainUnavailableReason.staleSource => (
        'Kaynak değişti',
        'Eski kaynak sürümüne ait açıklamayı göstermiyoruz. Güncel kaynakla yeniden dene.',
        true,
      ),
      GroundedExplainUnavailableReason.temporaryFailure => (
        'Açıklama şu anda alınamadı',
        'Kaynağın etkilenmedi. Biraz sonra yeniden deneyebilirsin.',
        true,
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 42),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (retryable) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onRetry, child: const Text('Yeniden dene')),
            ],
          ],
        ),
      ),
    );
  }
}
