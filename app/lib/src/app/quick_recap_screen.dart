import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../generation/supabase_source_summary_gateway.dart';
import 'app_runtime.dart';

/// Source-grounded summary UI. No synthetic AI output is ever shown as genuine.
class QuickRecapScreen extends StatefulWidget {
  const QuickRecapScreen({required this.runtime, required this.materialId, super.key});
  final AppRuntime runtime;
  final MaterialId materialId;

  @override
  State<QuickRecapScreen> createState() => _QuickRecapScreenState();
}

class _QuickRecapScreenState extends State<QuickRecapScreen> {
  static const _gateway = SupabaseSourceSummaryGateway();
  String? _jobId;
  ServerSummaryStatus? _status;
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy || _jobId != null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final material = await widget.runtime.store.material(
        learner: widget.runtime.learner, materialId: widget.materialId);
      if (material == null) throw StateError('Material unavailable');
      final source = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner, materialId: widget.materialId);
      if (source == null) throw StateError('Source unavailable');
      final extracted = await widget.runtime.store.extractedContentForSource(
        learner: widget.runtime.learner,
        sourceVersionId: source.identity.sourceVersionId);
      if (extracted == null) throw StateError('Source text unavailable');
      final submission = await _gateway.submit(
        source: SourceIngestResult(material: material, sourceVersion: source, extractedContent: extracted));
      if (!mounted) return;
      setState(() => _jobId = submission.jobId);
      await _refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'Özet isteği gönderilemedi. Oturumunu ve bağlantını kontrol et.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy && _jobId == null) return;
    final id = _jobId;
    if (id == null) return;
    try {
      final status = await _gateway.status(id);
      if (mounted) setState(() { _status = status; _error = null; });
    } catch (_) {
      if (mounted) setState(() => _error = 'Özet durumu alınamadı. Tekrar deneyebilirsin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Recap')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Kaynağına bağlı AI özeti', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('Bu özellik yalnızca sunucunun gerçekten ürettiği özetleri gösterir. Model bağlantısı kurulana kadar sonuç üretilemez.'),
        const SizedBox(height: 20),
        if (_jobId == null)
          FilledButton.icon(onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.auto_awesome), label: const Text('Özet oluştur')),
        if (_busy) const LinearProgressIndicator(),
        if (_jobId != null && status?.summary == null) ...[
          Text('İş durumu: ${status?.state ?? "Gönderildi"}'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _refresh, child: const Text('Durumu yenile')),
        ],
        if (status?.summary != null) ...[
          Text(status!.summary!, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          for (final point in status.keyPoints) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('• $point')),
          const Text('AI tarafından oluşturuldu · Kaynak metne dayalı'),
        ],
        if (status?.state.startsWith('FAILED') == true)
          const Text('Özet üretimi başarısız oldu. Aynı işi otomatik yeniden göndermiyoruz.'),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ]),
    );
  }
}
