import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../generation/grounded_explain_gateway.dart';
import 'app_runtime.dart';
import 'explain_back_screen.dart';
import 'learning_slice_screen.dart';

class ExplainScreen extends StatefulWidget {
  const ExplainScreen({
    required this.runtime,
    required this.source,
    super.key,
  });

  final AppRuntime runtime;
  final SourceVersionRecord source;

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

  Future<GroundedExplainResult> _request() => widget.runtime.explain.explain(
    GroundedExplainRequest(
      materialId: widget.source.identity.materialId,
      sourceVersionId: widget.source.identity.sourceVersionId,
      sourceContentDigest: widget.source.identity.contentDigest,
      outputLocale: 'tr-TR',
    ),
  );

  void _retry() => setState(() => _result = _request());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Açıkla')),
    body: SafeArea(
      child: FutureBuilder<GroundedExplainResult>(
        future: _result,
        builder: (context, snapshot) {
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
        Text('Kaynağına dayalı açıklama', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Bu bölüm kaynak metnin kendisi değil; kaynağına bağlı üretilmiş bir açıklamadır.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Text(result.explanation, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
        if (result.keyPoints.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Önemli noktalar', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final point in result.keyPoints)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const Text('•  '), Expanded(child: Text(point))],
              ),
            ),
        ],
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Açıklamayı okumak öğrenme kanıtı oluşturmaz. Hazır olduğunda kendi cümlelerinle anlat veya Hatırla ile aktif olarak dene.'),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => ExplainBackScreen(runtime: runtime, source: source)),
          ),
          icon: const Icon(Icons.record_voice_over_outlined),
          label: const Text('Kendi cümlelerinle anlat'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => LearningSliceScreen(runtime: runtime)),
          ),
          icon: const Icon(Icons.psychology_alt_outlined),
          label: const Text('Hatırla ile dene'),
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
