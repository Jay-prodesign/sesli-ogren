import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/learning_contracts.dart';

enum ImageTextExtractionFailureKind { emptyFile, tooLarge, unsupportedFormat, noExtractableText, recognitionFailure }

class ExtractedImageText {
  const ExtractedImageText({required this.text, required this.anchors, this.warnings = const []});

  final String text;
  final List<SourceAnchor> anchors;
  final List<String> warnings;
}

abstract interface class ImageTextExtractor {
  Future<ExtractedImageText> extract(Uint8List bytes, {required String sourceName});
}

class MlKitImageTextExtractor implements ImageTextExtractor {
  const MlKitImageTextExtractor({this.maxSourceBytes = 15 * 1024 * 1024, this.maxExtractedCharacters = 120000});

  final int maxSourceBytes;
  final int maxExtractedCharacters;

  @override
  Future<ExtractedImageText> extract(Uint8List bytes, {required String sourceName}) async {
    if (bytes.isEmpty) {
      throw const ImageTextExtractionException(
        'Image source cannot be empty.',
        kind: ImageTextExtractionFailureKind.emptyFile,
      );
    }
    if (bytes.length > maxSourceBytes) {
      throw const ImageTextExtractionException(
        'Image source exceeds the bounded byte safety limit.',
        kind: ImageTextExtractionFailureKind.tooLarge,
      );
    }
    final extension = _extension(sourceName);
    if (!const {'jpg', 'jpeg', 'png', 'heic', 'heif'}.contains(extension)) {
      throw const ImageTextExtractionException(
        'Image type is not supported for OCR.',
        kind: ImageTextExtractionFailureKind.unsupportedFormat,
      );
    }

    final directory = await Directory.systemTemp.createTemp('sesli-ogren-ocr-');
    final file = File('${directory.path}/source.$extension');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      await file.writeAsBytes(bytes, flush: true);
      final recognized = await recognizer.processImage(InputImage.fromFilePath(file.path));
      final buffer = StringBuffer();
      final anchors = <SourceAnchor>[];
      for (final block in recognized.blocks) {
        final text = _normalize(block.text);
        if (text.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write('\n\n');
        final start = buffer.length;
        if (start + text.length > maxExtractedCharacters) {
          throw const ImageTextExtractionException(
            'OCR text exceeds the bounded safety limit.',
            kind: ImageTextExtractionFailureKind.tooLarge,
          );
        }
        buffer.write(text);
        anchors.add(SourceAnchor(startOffset: start, endOffset: buffer.length, pageNumber: 1));
      }
      final text = buffer.toString();
      if (text.isEmpty) {
        throw const ImageTextExtractionException(
          'No trustworthy text could be recognized in this image.',
          kind: ImageTextExtractionFailureKind.noExtractableText,
        );
      }
      return ExtractedImageText(
        text: text,
        anchors: List.unmodifiable(anchors),
        warnings: const ['OCR_TEXT_REQUIRES_SOURCE_CHECK'],
      );
    } on ImageTextExtractionException {
      rethrow;
    } catch (_) {
      throw const ImageTextExtractionException(
        'Image OCR could not be completed safely.',
        kind: ImageTextExtractionFailureKind.recognitionFailure,
      );
    } finally {
      await recognizer.close();
      try {
        await directory.delete(recursive: true);
      } catch (_) {
        // Temp cleanup failure must not mutate learning truth.
      }
    }
  }

  static String _extension(String name) {
    final normalized = name.trim().toLowerCase();
    final dot = normalized.lastIndexOf('.');
    return dot < 0 ? '' : normalized.substring(dot + 1);
  }

  static String _normalize(String text) => text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
}

class ImageTextExtractionException implements Exception {
  const ImageTextExtractionException(this.message, {required this.kind});

  final String message;
  final ImageTextExtractionFailureKind kind;

  @override
  String toString() => 'ImageTextExtractionException: $message';
}
