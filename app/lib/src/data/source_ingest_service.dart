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
    this.maxTextCharacters = 200000,
    this.maxPdfBytes = 25 * 1024 * 1024,
  }) : _store = store,
       _pdfTextExtractor = pdfTextExtractor,
       _now = now ?? DateTime.now;

  final SourceStore _store;
  final PdfTextExtractor _pdfTextExtractor;
  final DateTime Function() _now;
  final int maxTextCharacters;
  final int maxPdfBytes;

  Future<SourceIngestResult> ingestPastedText({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required String text,
    String sourceName = 'Pasted text',
  }) async {
    _requireIdentity(learner: learner, materialId: materialId);
    if (text.trim().isEmpty) {
      throw const SourceIngestException('Pasted text cannot be empty.');
    }
    if (text.length > maxTextCharacters) {
      throw const SourceIngestException(
        'Pasted text exceeds the bounded M5 source limit.',
      );
    }

    final normalized = _normalizeText(text);
    if (normalized.length > maxTextCharacters) {
      throw const SourceIngestException(
        'Normalized text exceeds the bounded M5 source limit.',
      );
    }

    final sourceBytes = utf8.encode(text);
    final digest = sha256.convert(sourceBytes).toString();
    return _persist(
      learner: learner,
      materialId: materialId,
      digest: digest,
      mediaType: SourceMediaType.pastedText,
      sourceName: _validatedTitle(sourceName, fallback: 'Pasted text'),
      mimeType: 'text/plain; charset=utf-8',
      byteSize: sourceBytes.length,
      inlineText: text,
      extractedText: normalized,
      extractionMethod: 'inline_text',
      extractionMethodVersion: 'v1',
      anchors: [
        SourceAnchor(startOffset: 0, endOffset: normalized.length),
      ],
    );
  }

  Future<SourceIngestResult> ingestPdf({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required Uint8List bytes,
    required String originalName,
  }) async {
    _requireIdentity(learner: learner, materialId: materialId);
    if (bytes.isEmpty) {
      throw const SourceIngestException('PDF cannot be empty.');
    }
    if (bytes.length > maxPdfBytes) {
      throw const SourceIngestException(
        'PDF exceeds the bounded M5 byte safety limit.',
      );
    }
    if (!_hasPdfHeader(bytes)) {
      throw const SourceIngestException(
        'Selected file is not a supported PDF source.',
      );
    }

    final safeName = _validatedTitle(
      _safeFileName(originalName),
      fallback: 'document.pdf',
    );
    final ExtractedPdf extracted;
    try {
      extracted = await _pdfTextExtractor.extract(
        bytes,
        sourceName: safeName,
      );
    } on PdfTextExtractionException catch (error) {
      throw SourceIngestException(error.message);
    } catch (_) {
      throw const SourceIngestException('PDF could not be processed safely.');
    }

    if (extracted.text.length > maxTextCharacters) {
      throw const SourceIngestException(
        'PDF extracted text exceeds the bounded M5 source limit.',
      );
    }

    final digest = sha256.convert(bytes).toString();
    return _persist(
      learner: learner,
      materialId: materialId,
      digest: digest,
      mediaType: SourceMediaType.pdf,
      sourceName: safeName,
      mimeType: 'application/pdf',
      byteSize: bytes.length,
      rawSourceBytes: bytes,
      extractedText: extracted.text,
      extractionMethod: 'pdfrx_text',
      extractionMethodVersion: 'pdfrx-2.6.1',
      anchors: extracted.anchors,
    );
  }

  Future<SourceIngestResult> _persist({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required String digest,
    required SourceMediaType mediaType,
    required String sourceName,
    required String mimeType,
    required int byteSize,
    required String extractedText,
    required String extractionMethod,
    required String extractionMethodVersion,
    required List<SourceAnchor> anchors,
    String? inlineText,
    Uint8List? rawSourceBytes,
  }) {
    _requireIdentity(learner: learner, materialId: materialId);

    final versionDigest = sha256
        .convert(
          utf8.encode(
            '${learner.id.value}\u0000${materialId.value}\u0000'
            '${mediaType.name}\u0000$digest',
          ),
        )
        .toString();
    final sourceVersionId = SourceVersionId(
      'sv_${versionDigest.substring(0, 32)}',
    );
    final extractionDigest = sha256
        .convert(
          utf8.encode(
            '${sourceVersionId.value}\u0000$extractionMethod\u0000'
            '$extractionMethodVersion\u0000'
            '${sha256.convert(utf8.encode(extractedText))}',
          ),
        )
        .toString();
    final now = _now().toUtc();

    final material = MaterialRecord(
      id: materialId,
      title: sourceName,
      mediaType: mediaType,
      lifecycleStatus: MaterialLifecycleStatus.active,
      processingState: MaterialProcessingState.ready,
      currentSourceVersionId: sourceVersionId,
      createdAt: now,
      updatedAt: now,
    );
    final sourceVersion = SourceVersionRecord(
      identity: SourceVersionIdentity(
        materialId: materialId,
        sourceVersionId: sourceVersionId,
        contentDigest: digest,
        trustClass: SourceTrustClass.userProvided,
        knowledgeClass: SourceKnowledgeClass.learnerOwned,
      ),
      mediaType: mediaType,
      sourceName: sourceName,
      mimeType: mimeType,
      byteSize: byteSize,
      inlineText: inlineText,
      createdAt: now,
    );
    final extractedContent = ExtractedContentRecord(
      id: ExtractedContentId('ex_${extractionDigest.substring(0, 32)}'),
      sourceVersionId: sourceVersionId,
      normalizedText: extractedText,
      method: extractionMethod,
      methodVersion: extractionMethodVersion,
      anchors: List.unmodifiable(anchors),
      warnings: const [],
      sourceContentDigest: digest,
      createdAt: now,
    );

    return _store.persistIngestResult(
      learner: learner,
      material: material,
      sourceVersion: sourceVersion,
      extractedContent: extractedContent,
      rawSourceBytes: rawSourceBytes,
    );
  }

  static void _requireIdentity({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
  }) {
    if (learner.id.value.trim().isEmpty) {
      throw const SourceIngestException('Learner identity cannot be empty.');
    }
    if (materialId.value.trim().isEmpty) {
      throw const SourceIngestException('Material ID cannot be empty.');
    }
  }

  static bool _hasPdfHeader(Uint8List bytes) {
    if (bytes.length < 5) {
      return false;
    }
    final searchLimit = bytes.length < 1024 ? bytes.length - 4 : 1020;
    for (var index = 0; index < searchLimit; index++) {
      if (bytes[index] == 0x25 &&
          bytes[index + 1] == 0x50 &&
          bytes[index + 2] == 0x44 &&
          bytes[index + 3] == 0x46 &&
          bytes[index + 4] == 0x2D) {
        return true;
      }
    }
    return false;
  }

  static String _normalizeText(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  static String _validatedTitle(
    String value, {
    required String fallback,
  }) {
    final trimmed = value.trim();
    final resolved = trimmed.isEmpty ? fallback : trimmed;
    if (resolved.length > 300) {
      throw const SourceIngestException(
        'Source title exceeds the bounded M5 title limit.',
      );
    }
    return resolved;
  }

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
