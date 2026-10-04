import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../domain/learning_contracts.dart';

class ExtractedPdf {
  const ExtractedPdf({
    required this.text,
    required this.anchors,
    required this.pageCount,
  });

  final String text;
  final List<SourceAnchor> anchors;
  final int pageCount;
}

abstract interface class PdfTextExtractor {
  Future<ExtractedPdf> extract(Uint8List bytes, {required String sourceName});
}

class PdfrxPdfTextExtractor implements PdfTextExtractor {
  const PdfrxPdfTextExtractor();

  @override
  Future<ExtractedPdf> extract(
    Uint8List bytes, {
    required String sourceName,
  }) async {
    final document = await PdfDocument.openData(bytes, sourceName: sourceName);
    try {
      final buffer = StringBuffer();
      final anchors = <SourceAnchor>[];
      for (var index = 0; index < document.pages.length; index++) {
        final rawText = await document.pages[index].loadText();
        final pageText = _normalize(rawText?.fullText ?? '');
        if (pageText.isEmpty) {
          continue;
        }
        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        final start = buffer.length;
        buffer.write(pageText);
        anchors.add(
          SourceAnchor(
            startOffset: start,
            endOffset: buffer.length,
            pageNumber: index + 1,
          ),
        );
      }
      final extracted = buffer.toString();
      if (extracted.isEmpty) {
        throw const PdfTextExtractionException(
          'PDF contains no extractable text. OCR is not enabled in M5.',
        );
      }
      return ExtractedPdf(
        text: extracted,
        anchors: List.unmodifiable(anchors),
        pageCount: document.pages.length,
      );
    } finally {
      await document.dispose();
    }
  }

  static String _normalize(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
}

class PdfTextExtractionException implements Exception {
  const PdfTextExtractionException(this.message);

  final String message;

  @override
  String toString() => 'PdfTextExtractionException: $message';
}
