import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../learning/explain_back_gateway.dart';
import 'app_runtime.dart';

class ExplainBackScreen extends StatefulWidget {
  const ExplainBackScreen({required this.runtime, required this.source, super.key});

  final AppRuntime runtime;
  final SourceVersionRecord source;

  @override
  State<ExplainBackScreen> createState() => _ExplainBackScreenState();
}

class _ExplainBackScreenState extends State<ExplainBackScreen> {
  final _controller = TextEditingController();
  ExplainBackResult? _result;
  bool _submitting = false;
  int _attemptOrdinal = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final response = _controller.text.trim();
    if (response.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final ordinal = _attemptOrdinal++;
    final digest = sha256
        .convert(utf8.encode('${widget.runtime.learner.id.value}\u0000${widget.source.identity.sourceVersionId.value}\u0000$ordinal\u0000$response'))
        .toString();
    final result = await widget.runtime.explainBack.evaluate(
      ExplainBackRequest(
        attemptId: ExplainBackAttemptId('explain-${digest.substring(0, 32)}'),
        materialId: widget.source.identity.materialId,
        sourceVersionId: widget.source.identity.sourceVersionId,
        sourceContentDigest: widget.source.identity.contentDigest,
        response: response,
        outputLocale: 'tr-TR',
      ),
    );
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
            Text(
              'Kaynağa bakmadan, anladığını kendi cümlelerinle açıkla.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Bu aktif deneme değerlendirilmeden öğrenme kanıtı veya ustalık iddiası oluşturmaz.'),
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Henüz güvenilir değerlendirme yok', style: Theme.of(context).textTheme.titleMedium),
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
    final title = switch (result.kind) {
      ExplainBackEvaluationKind.sufficient => 'Anlatımında temel fikirler görünüyor',
      ExplainBackEvaluationKind.gapDetected => 'Bir noktayı güçlendirebiliriz',
      ExplainBackEvaluationKind.notEvaluable => 'Bu yanıttan güvenilir sonuç çıkaramıyoruz',
      ExplainBackEvaluationKind.unavailable => 'Değerlendirme kullanılamıyor',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.feedback),
            if (result.targetedRepair.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Hedefli düzeltme', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(result.targetedRepair),
            ],
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Tekrar kendi cümlelerimle anlat')),
          ],
        ),
      ),
    );
  }
}
