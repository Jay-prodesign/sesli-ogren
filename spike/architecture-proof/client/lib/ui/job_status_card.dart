// PROOF-ONLY UI (D-028): demonstrates the queued/processing/success/failure/retry states the
// Architecture Proof must expose. It is not product design and must not be reused as such.
import 'package:flutter/material.dart';

import '../domain/models.dart';

class JobStatusCard extends StatelessWidget {
  const JobStatusCard({super.key, required this.job, required this.onRetry});

  final GenerationJobView job;
  final VoidCallback onRetry;

  static const _labels = <ProcessingView, String>{
    ProcessingView.queued: 'Sırada',
    ProcessingView.processing: 'Hazırlanıyor',
    ProcessingView.success: 'Özet hazır',
    ProcessingView.failedRetryable: 'Özet oluşturulamadı',
    ProcessingView.checking: 'Durum kontrol ediliyor',
    ProcessingView.failedFinal: 'Bu kaynak için özet oluşturulamadı',
  };

  @override
  Widget build(BuildContext context) {
    final view = job.view;
    return Semantics(
      container: true,
      label: 'proof-ui job status',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (view == ProcessingView.queued || view == ProcessingView.processing || view == ProcessingView.checking)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text(_labels[view]!, key: const Key('job-status-label'))),
              if (job.canRetry)
                TextButton(key: const Key('job-retry'), onPressed: onRetry, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      ),
    );
  }
}
