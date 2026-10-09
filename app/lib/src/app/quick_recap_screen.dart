import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../generation/supabase_source_summary_gateway.dart';
import 'app_runtime.dart';
import 'listen_screen.dart';
import 'learning_slice_screen.dart';
import 'explain_screen.dart';

/// Source-grounded summary UI. No synthetic AI output is ever shown as genuine.
class QuickRecapScreen extends StatefulWidget {
  const QuickRecapScreen({required this.runtime, required this.materialId, super.key});
  final AppRuntime runtime;
  final MaterialId materialId;

  @override
  State<QuickRecapScreen> createState() => _QuickRecapScreenState();
}

class _QuickRecapScreenState extends State<QuickRecapScreen> with WidgetsBindingObserver {
  static const _gateway = SupabaseSourceSummaryGateway();
  String? _jobId;
  SourceVersionId? _submittedSourceVersion;
  ServerSummaryStatus? _status;
  String? _error;
  bool _busy = false;
  bool _restoring = true;
  bool _checking = false;
  bool _dispatching = false;
  Timer? _pollTimer;

  Future<void> _dispatchCurrent() async {
    final id = _jobId;
    if (id == null || !mounted || _dispatching) return;
    setState(() {
      _dispatching = true;
      _error = null;
    });
    final accepted = await _gateway.dispatch(id);
    if (!mounted) return;
    setState(() => _dispatching = false);
    if (_jobId != id) return;
    if (!accepted) {
      setState(() => _error = 'Özet kuyruğa alındı ancak sunucu işlemi başlatılamadı. Tekrar deneyebilirsin.');
      return;
    }
    await _refresh();
  }

  Future<void> _retryCurrent() async {
    final id = _jobId;
    if (id == null || !mounted || _dispatching) return;
    setState(() {
      _dispatching = true;
      _error = null;
    });
    final accepted = await _gateway.retry(id);
    if (!mounted) return;
    setState(() => _dispatching = false);
    if (_jobId != id) return;
    if (!accepted) {
      setState(
        () => _error = 'Bu özet işi güvenli biçimde yeniden sıraya alınamadı. Daha sonra tekrar dene veya sunucu durumunu kontrol et.',
      );
      return;
    }
    await _refresh();
    if (mounted && _jobId == id && !(_status?.isTerminal ?? false)) {
      _startPolling();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    try {
      final source = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (source == null) return;
      final id = await widget.runtime.store.summaryJobId(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
        sourceVersionId: source.identity.sourceVersionId,
      );
      if (!mounted || id == null) return;
      setState(() {
        _jobId = id;
        _submittedSourceVersion = source.identity.sourceVersionId;
      });
      await _refresh();
      if (mounted && _jobId != null && !(_status?.isTerminal ?? false)) {
        if (_status?.state == 'QUEUED' || _status?.state == 'PROCESSING') {
          unawaited(_dispatchCurrent());
        }
        _startPolling();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Önceki özet işi yüklenemedi.');
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _jobId != null) {
      unawaited(_refreshAndRecover());
    }
  }

  Future<void> _refreshAndRecover() async {
    await _refresh();
    if (!mounted || _jobId == null || (_status?.isTerminal ?? false)) return;
    if (_status?.state == 'QUEUED' || _status?.state == 'PROCESSING') {
      await _dispatchCurrent();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_checking && mounted) {
        _refresh();
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || _restoring || _jobId != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final material = await widget.runtime.store.material(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (material == null) throw StateError('Material unavailable');
      final source = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (source == null) throw StateError('Source unavailable');
      final extracted = await widget.runtime.store.extractedContentForSource(
        learner: widget.runtime.learner,
        sourceVersionId: source.identity.sourceVersionId,
      );
      if (extracted == null) throw StateError('Source text unavailable');
      final existingJobId = await widget.runtime.store.summaryJobId(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
        sourceVersionId: source.identity.sourceVersionId,
      );
      if (existingJobId != null) {
        if (!mounted) return;
        setState(() {
          _jobId = existingJobId;
          _submittedSourceVersion = source.identity.sourceVersionId;
        });
        await _refresh();
        if (mounted && _jobId != null && !(_status?.isTerminal ?? false)) {
          if (_status?.state == 'QUEUED' || _status?.state == 'PROCESSING') {
            unawaited(_dispatchCurrent());
          }
          _startPolling();
        }
        return;
      }
      final staleServerMaterialId = await widget.runtime.store.summaryServerMaterialId(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (staleServerMaterialId != null) {
        final removed = await _gateway.deleteServerMaterial(staleServerMaterialId);
        if (!removed) {
          throw const ServerSummarySubmissionException('Previous server source could not be removed.');
        }
        await widget.runtime.store.clearSummaryJob(
          learner: widget.runtime.learner,
          materialId: widget.materialId,
        );
      }

      final submission = await _gateway.submit(
        source: SourceIngestResult(material: material, sourceVersion: source, extractedContent: extracted),
      );
      await widget.runtime.store.saveSummaryJob(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
        sourceVersionId: source.identity.sourceVersionId,
        serverMaterialId: submission.materialId,
        jobId: submission.jobId,
      );
      if (!mounted) return;
      final currentSource = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (!mounted) return;
      if (currentSource?.identity.sourceVersionId != source.identity.sourceVersionId) {
        final removed = await _gateway.deleteServerMaterial(submission.materialId);
        if (removed) {
          await widget.runtime.store.clearSummaryJob(
            learner: widget.runtime.learner,
            materialId: widget.materialId,
          );
        }
        if (mounted) {
          setState(() => _error = 'Kaynak değişti. Yeni sürüm için özet oluşturabilirsin.');
        }
        return;
      }
      setState(() {
        _jobId = submission.jobId;
        _submittedSourceVersion = source.identity.sourceVersionId;
      });
      unawaited(_dispatchCurrent());
      await _refresh();
      if (mounted && _jobId != null && !(_status?.isTerminal ?? false)) {
        _startPolling();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Özet isteği gönderilemedi. Oturumunu ve bağlantını kontrol et.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (_checking || !mounted) return;
    if (_busy && _jobId == null) return;
    final id = _jobId;
    if (id == null) return;
    _checking = true;
    try {
      final status = await _gateway.status(id);
      final currentSource = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (!mounted || _jobId != id) return;
      if (currentSource?.identity.sourceVersionId != _submittedSourceVersion) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _jobId = null;
            _submittedSourceVersion = null;
            _status = null;
            _error = 'Kaynak değişti. Yeni sürüm için özet oluşturabilirsin.';
          });
        }
        return;
      }
      if (_jobId != id || !mounted) return;
      if (status.isTerminal) {
        _pollTimer?.cancel();
      }
      if (mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && _jobId == id) setState(() => _error = 'Özet durumu alınamadı. Tekrar deneyebilirsin.');
    } finally {
      _checking = false;
    }
  }

  Future<void> _openRecall() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LearningSliceScreen(runtime: widget.runtime, materialId: widget.materialId),
    ),
  );

  Future<void> _openExplain() async {
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (!mounted || source == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExplainScreen(runtime: widget.runtime, source: source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Recap')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Kaynağına bağlı AI özeti', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
            'Bu özellik yalnızca sunucunun gerçekten ürettiği özetleri gösterir. Model bağlantısı kurulana kadar sonuç üretilemez.',
          ),
          const SizedBox(height: 20),
          if (_jobId == null)
            FilledButton.icon(
              onPressed: (_busy || _restoring) ? null : _submit,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Özet oluştur'),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_jobId != null && status?.summary == null) ...[
            Text('İş durumu: ${status?.state ?? "Gönderildi"}'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _dispatching ? null : _refresh, child: const Text('Durumu yenile')),
            if (status?.state == 'QUEUED' || status?.state == 'PROCESSING') ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _dispatching ? null : _dispatchCurrent,
                child: Text(
                  status?.state == 'PROCESSING'
                      ? 'İşlem takıldıysa güvenle kontrol et'
                      : 'İşlemi başlatmayı tekrar dene',
                ),
              ),
            ],
            if (status?.state == 'FAILED_RETRYABLE' && status?.failureClass != 'reconciliation_required') ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _dispatching ? null : _retryCurrent,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Güvenli yeniden dene'),
              ),
            ],
            if (_dispatching) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
          ],
          if (status?.summary != null) ...[
            Text(status!.summary!, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            for (final point in status.keyPoints)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $point')),
            const Text('AI tarafından oluşturuldu · Kaynak metne dayalı'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (routeContext) => ListenScreen(
                        runtime: widget.runtime,
                        materialId: widget.materialId,
                        onRecall: () {
                          Navigator.of(routeContext).pop();
                          _openRecall();
                        },
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.headphones),
                  label: const Text('Dinle'),
                ),
                OutlinedButton.icon(
                  onPressed: _openRecall,
                  icon: const Icon(Icons.psychology_alt_outlined),
                  label: const Text('Hatırla'),
                ),
                OutlinedButton.icon(
                  onPressed: _openExplain,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Açıkla'),
                ),
              ],
            ),
          ],
          if (status?.failureClass == 'reconciliation_required')
            const Text(
              'Önceki model çağrısının sonucu belirsiz. Çifte üretim veya çifte ücret riskini önlemek için otomatik yeniden deneme kapalı.',
            )
          else if (status?.state == 'FAILED_FINAL')
            const Text('Özet üretimi tamamlanamadı. Aynı işi otomatik yeniden göndermiyoruz.')
          else if (status?.state == 'FAILED_RETRYABLE')
            const Text('Özet üretimi geçici olarak başarısız oldu. Güvenli yeniden deneme kullanılabilir.'),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }
}
