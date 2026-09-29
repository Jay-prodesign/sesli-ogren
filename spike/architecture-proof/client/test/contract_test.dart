// LA-0013 client contract: decode the rows the database actually returned to the owner
// (fixture captured by db/tests/11_canonical_flow_reopen.sql) into canonical models.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_spike_client/domain/models.dart';
import 'package:la_spike_client/ui/job_status_card.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/owner_rows.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('library projection points at a persisted, versioned Summary Artifact with lineage', () {
    final rows = _fixture();
    final item = LibraryItem.fromRow(rows['library_item'] as Map<String, dynamic>);
    final artifact = SummaryArtifact.fromRow(rows['artifact'] as Map<String, dynamic>);
    final job = GenerationJobView.fromRow(rows['job'] as Map<String, dynamic>);

    expect(item.processingState, 'ready');
    expect(item.hasSummary, isTrue);
    expect(item.summaryArtifactId, artifact.id);
    expect(item.summaryVersion, artifact.version);
    expect(artifact.materialId, item.materialId);
    expect(artifact.generationJobId, job.jobId);
    expect(artifact.summary, isNotEmpty);
    expect(artifact.keyPoints, isNotEmpty);
    expect(artifact.language, 'tr-TR');
    expect(artifact.aiGenerated, isTrue);
    expect(job.view, ProcessingView.success);
  });

  test('client-visible job row carries no worker lease internals', () {
    final job = _fixture()['job'] as Map<String, dynamic>;
    expect(job.containsKey('lease_token'), isFalse);
    expect(job.containsKey('lease_expires_at'), isFalse);
  });

  test('non-summary or unknown-schema artifacts are rejected, not coerced', () {
    final row = Map<String, dynamic>.from(_fixture()['artifact'] as Map<String, dynamic>);
    expect(() => SummaryArtifact.fromRow({...row, 'artifact_type': 'QUIZ'}), throwsFormatException);
    expect(() => SummaryArtifact.fromRow({...row, 'content_schema_version': 2}), throwsFormatException);
  });

  test('canonical job states map to the required user-visible states', () {
    GenerationJobView v(String s, [String? f]) => GenerationJobView(jobId: 'j', state: s, failureClass: f);
    expect(v('QUEUED').view, ProcessingView.queued);
    expect(v('PROCESSING').view, ProcessingView.processing);
    expect(v('SUCCEEDED').view, ProcessingView.success);
    expect(v('FAILED_RETRYABLE', 'retryable').view, ProcessingView.failedRetryable);
    expect(v('FAILED_RETRYABLE', 'retryable').canRetry, isTrue);
    expect(v('FAILED_RETRYABLE', 'reconciliation_required').view, ProcessingView.checking);
    expect(v('FAILED_RETRYABLE', 'reconciliation_required').canRetry, isFalse);
    expect(v('FAILED_FINAL').canRetry, isFalse);
    expect(v('CANCELLED').view, ProcessingView.failedFinal);
  });

  testWidgets('proof UI offers retry only for a plain retryable failure', (tester) async {
    var retries = 0;
    Future<void> pump(GenerationJobView job) => tester.pumpWidget(
          MaterialApp(home: Scaffold(body: JobStatusCard(job: job, onRetry: () => retries++))),
        );

    await pump(const GenerationJobView(jobId: 'j', state: 'FAILED_RETRYABLE', failureClass: 'retryable'));
    expect(find.text('Özet oluşturulamadı'), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-retry')));
    expect(retries, 1);

    await pump(const GenerationJobView(jobId: 'j', state: 'FAILED_RETRYABLE', failureClass: 'reconciliation_required'));
    expect(find.text('Durum kontrol ediliyor'), findsOneWidget);
    expect(find.byKey(const Key('job-retry')), findsNothing);

    await pump(const GenerationJobView(jobId: 'j', state: 'SUCCEEDED'));
    expect(find.text('Özet hazır'), findsOneWidget);
    expect(find.byKey(const Key('job-retry')), findsNothing);
  });
}
