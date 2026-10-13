import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../domain/learning_contracts.dart';
import 'legacy_office_text_extractor.dart';

enum OfficeSourceFormat { docx, pptx, doc, ppt }

enum OfficeTextExtractionFailureKind {
  emptyFile,
  tooLarge,
  unsupportedFormat,
  invalidContainer,
  encryptedOrCorrupt,
  noExtractableText,
  textLimit,
}

class ExtractedOfficeText {
  const ExtractedOfficeText({
    required this.text,
    required this.anchors,
    required this.format,
    required this.unitCount,
    this.warnings = const [],
  });

  final String text;
  final List<SourceAnchor> anchors;
  final OfficeSourceFormat format;
  final int unitCount;
  final List<String> warnings;
}

abstract interface class OfficeTextExtractor {
  Future<ExtractedOfficeText> extract(Uint8List bytes, {required String sourceName});
}

class OpenXmlOfficeTextExtractor implements OfficeTextExtractor {
  const OpenXmlOfficeTextExtractor({
    this.maxSourceBytes = 25 * 1024 * 1024,
    this.maxArchiveEntries = 12000,
    this.maxInflatedBytes = 96 * 1024 * 1024,
    this.maxExtractedCharacters = 200000,
  });

  final int maxSourceBytes;
  final int maxArchiveEntries;
  final int maxInflatedBytes;
  final int maxExtractedCharacters;

  @override
  Future<ExtractedOfficeText> extract(Uint8List bytes, {required String sourceName}) async {
    if (bytes.isEmpty) {
      throw const OfficeTextExtractionException(
        'Office source cannot be empty.',
        kind: OfficeTextExtractionFailureKind.emptyFile,
      );
    }
    if (bytes.length > maxSourceBytes) {
      throw const OfficeTextExtractionException(
        'Office source exceeds the bounded byte safety limit.',
        kind: OfficeTextExtractionFailureKind.tooLarge,
      );
    }

    final format = _formatFromName(sourceName);
    if (format == OfficeSourceFormat.doc || format == OfficeSourceFormat.ppt) {
      final legacy = const LegacyOfficeTextExtractor().extract(bytes, format: format);
      if (legacy.text.length > maxExtractedCharacters) {
        throw const OfficeTextExtractionException(
          'Legacy Office extracted text exceeds the bounded safety limit.',
          kind: OfficeTextExtractionFailureKind.textLimit,
        );
      }
      return ExtractedOfficeText(
        text: legacy.text,
        anchors: legacy.anchors,
        format: format,
        unitCount: legacy.anchors.length,
        warnings: legacy.warnings,
      );
    }
    if (!_hasZipHeader(bytes)) {
      throw const OfficeTextExtractionException(
        'Office source is not a valid Open XML container.',
        kind: OfficeTextExtractionFailureKind.invalidContainer,
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const OfficeTextExtractionException(
        'Office source could not be opened safely.',
        kind: OfficeTextExtractionFailureKind.encryptedOrCorrupt,
      );
    }
    if (archive.length > maxArchiveEntries) {
      throw const OfficeTextExtractionException(
        'Office source contains too many archive entries.',
        kind: OfficeTextExtractionFailureKind.tooLarge,
      );
    }

    var inflatedBytes = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      inflatedBytes += entry.size;
      if (inflatedBytes > maxInflatedBytes) {
        throw const OfficeTextExtractionException(
          'Office source expands beyond the bounded safety limit.',
          kind: OfficeTextExtractionFailureKind.tooLarge,
        );
      }
    }

    return switch (format) {
      OfficeSourceFormat.docx => _extractDocx(archive),
      OfficeSourceFormat.pptx => _extractPptx(archive),
      OfficeSourceFormat.doc || OfficeSourceFormat.ppt => throw StateError('legacy_office_dispatch_unreachable'),
    };
  }

  ExtractedOfficeText _extractDocx(Archive archive) {
    final entry = _entry(archive, 'word/document.xml');
    if (entry == null) {
      throw const OfficeTextExtractionException(
        'DOCX main document part is missing.',
        kind: OfficeTextExtractionFailureKind.invalidContainer,
      );
    }

    final document = _parseXml(entry);
    final paragraphs = <String>[];
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'p') continue;
      final buffer = StringBuffer();
      for (final node in element.descendants.whereType<XmlElement>()) {
        if (node.name.local == 't') {
          buffer.write(node.innerText);
        } else if (node.name.local == 'tab') {
          buffer.write('\t');
        } else if (node.name.local == 'br' || node.name.local == 'cr') {
          buffer.write('\n');
        }
      }
      final normalized = _normalizeUnit(buffer.toString());
      if (normalized.isNotEmpty) paragraphs.add(normalized);
    }

    return _compose(units: paragraphs, format: OfficeSourceFormat.docx, warning: 'DOCX_LAYOUT_NOT_PRESERVED');
  }

  ExtractedOfficeText _extractPptx(Archive archive) {
    final slides =
        archive.where((entry) => entry.isFile && RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(entry.name)).toList()
          ..sort((left, right) => _slideNumber(left.name).compareTo(_slideNumber(right.name)));
    if (slides.isEmpty) {
      throw const OfficeTextExtractionException(
        'PPTX contains no readable slide parts.',
        kind: OfficeTextExtractionFailureKind.invalidContainer,
      );
    }

    final units = <String>[];
    for (final slide in slides) {
      final document = _parseXml(slide);
      final lines = document.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 't')
          .map((element) => _normalizeUnit(element.innerText))
          .where((text) => text.isNotEmpty)
          .toList(growable: false);
      units.add(lines.join('\n'));
    }

    return _compose(units: units, format: OfficeSourceFormat.pptx, warning: 'PPTX_SLIDE_TEXT_ONLY', pageAnchors: true);
  }

  ExtractedOfficeText _compose({
    required List<String> units,
    required OfficeSourceFormat format,
    required String warning,
    bool pageAnchors = false,
  }) {
    final buffer = StringBuffer();
    final anchors = <SourceAnchor>[];
    var representedUnits = 0;
    for (var index = 0; index < units.length; index++) {
      final unit = units[index].trim();
      if (unit.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write('\n\n');
      final start = buffer.length;
      if (start + unit.length > maxExtractedCharacters) {
        throw const OfficeTextExtractionException(
          'Office extracted text exceeds the bounded safety limit.',
          kind: OfficeTextExtractionFailureKind.textLimit,
        );
      }
      buffer.write(unit);
      anchors.add(
        SourceAnchor(startOffset: start, endOffset: buffer.length, pageNumber: pageAnchors ? index + 1 : null),
      );
      representedUnits++;
    }
    final text = buffer.toString();
    if (text.trim().isEmpty) {
      throw const OfficeTextExtractionException(
        'Office source contains no extractable text.',
        kind: OfficeTextExtractionFailureKind.noExtractableText,
      );
    }
    return ExtractedOfficeText(
      text: text,
      anchors: List.unmodifiable(anchors),
      format: format,
      unitCount: representedUnits,
      warnings: [warning],
    );
  }

  static XmlDocument _parseXml(ArchiveFile entry) {
    try {
      final bytes = entry.readBytes();
      if (bytes == null) {
        throw const OfficeTextExtractionException(
          'Office XML part could not be read.',
          kind: OfficeTextExtractionFailureKind.encryptedOrCorrupt,
        );
      }
      return XmlDocument.parse(utf8.decode(bytes, allowMalformed: false));
    } on OfficeTextExtractionException {
      rethrow;
    } catch (_) {
      throw const OfficeTextExtractionException(
        'Office XML part is malformed.',
        kind: OfficeTextExtractionFailureKind.encryptedOrCorrupt,
      );
    }
  }

  static ArchiveFile? _entry(Archive archive, String name) {
    for (final entry in archive) {
      if (entry.isFile && entry.name == name) return entry;
    }
    return null;
  }

  static OfficeSourceFormat _formatFromName(String sourceName) {
    final lower = sourceName.trim().toLowerCase();
    if (lower.endsWith('.docx')) return OfficeSourceFormat.docx;
    if (lower.endsWith('.pptx')) return OfficeSourceFormat.pptx;
    if (lower.endsWith('.doc')) return OfficeSourceFormat.doc;
    if (lower.endsWith('.ppt')) return OfficeSourceFormat.ppt;
    throw const OfficeTextExtractionException(
      'Unsupported Office file extension.',
      kind: OfficeTextExtractionFailureKind.unsupportedFormat,
    );
  }

  static int _slideNumber(String name) {
    final match = RegExp(r'slide(\d+)\.xml$').firstMatch(name);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static bool _hasZipHeader(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);

  static String _normalizeUnit(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

class OfficeTextExtractionException implements Exception {
  const OfficeTextExtractionException(this.message, {required this.kind});

  final String message;
  final OfficeTextExtractionFailureKind kind;

  @override
  String toString() => 'OfficeTextExtractionException: $message';
}
