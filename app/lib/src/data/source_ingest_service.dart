import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import 'pdf_text_extractor.dart';
import 'source_store.dart';

class SourceIngestService {
  const SourceIngestService({
    required SourceStore store,
    required PdfTextExtractor pdfTextExtractor,
    DateTime Function()? now,
  }) : _store = store,
       _pdfTextExtractor = pdfTextExtractor,
       _now = now ?? DateTime.now;

  final SourceStore _store;
  final PdfTextExtractor _pdfTextExtractor;
  final DateTime Function() _now;

  Future<SourceVersionRecord> ingestPastedText({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required String text,
    String sourceName = 'Pasted text',
  }) async {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) {
      throw const SourceIngestException('Pasted text cannot be empty.');
    }
    final digest = sha256.convert(utf8.encode(normalized)).toString();
    return _persist(
      learner: learner,
      materialId: materialId,
      digest: digest,
      mediaType: SourceMediaType.pastedText,
      sourceName: sourceName.trim().isEmpty ? 'Pasted text' : sourceName.trim(),
      extractedText: normalized,
      anchors: [
        SourceAnchor(startOffset: 0, endOffset: normalized.length),
      ],
    );
  }

  Future<SourceVersionRecord> ingestPdf({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required Uint8List bytes,
    required String originalName,
  }) async {
    if (bytes.isEmpty) {
      throw const SourceIngestException('PDF cannot be empty.');
    }
    final safeName = _safeFileName(originalName);
    final extracted = await _pdfTextExtractor.extract(
      bytes,
      sourceName: safeName,
    );
    final digest = sha256.convert(bytes).toString();
    return _persist(
      learner: learner,
      materialId: materialId,
      digest: digest,
      mediaType: SourceMediaType.pdf,
      sourceName: safeName,
      extractedText: extracted.text,
      anchors: extracted.anchors,
    );
  }

  Future<SourceVersionRecord> _persist({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required String digest,
    required SourceMediaType mediaType,
    required String sourceName,
    required String extractedText,
    required List<SourceAnchor> anchors,
  }) {
    if (materialId.value.trim().isEmpty) {
      throw const SourceIngestException('Material ID cannot be empty.');
    }
    final versionDigest = sha256
        .convert(
          utf8.encode(
            '${learner.id.value}\u0000${materialId.value}\u0000$digest',
          ),
        )
        .toString();
    final record = SourceVersionRecord(
      identity: SourceVersionIdentity(
        materialId: materialId,
        sourceVersionId: SourceVersionId('sv_${versionDigest.substring(0, 32)}'),
        contentDigest: digest,
        trustClass: SourceTrustClass.userProvided,
      ),
      mediaType: mediaType,
      sourceName: sourceName,
      extractedText: extractedText,
      anchors: List.unmodifiable(anchors),
      createdAt: _now().toUtc(),
    );
    return _store.persistSourceVersion(
      learner: learner,
      sourceVersion: record,
    );
  }

  static String _normalizeText(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  static String _safeFileName(String value) {
    final pieces = value.split(RegExp(r'[\\/]'));
    final candidate = pieces.isEmpty ? value : pieces.last;
    final trimmed = candidate.trim();
    return trimmed.isEmpty ? 'document.pdf' : trimmed;
  }
}

class SourceIngestException implements Exception {
  const SourceIngestException(this.message);

  final String message;

  @override
  String toString() => 'SourceIngestException: $message';
}
