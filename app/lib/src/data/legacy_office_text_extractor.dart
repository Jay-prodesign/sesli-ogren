import 'dart:typed_data';

import 'package:quds_office_engine/quds_office_engine.dart' show CfbfException, CfbfFile;

import '../domain/learning_contracts.dart';
import 'office_text_extractor.dart'
    show OfficeSourceFormat, OfficeTextExtractionException, OfficeTextExtractionFailureKind;

class ExtractedLegacyOfficeText {
  const ExtractedLegacyOfficeText({required this.text, required this.anchors, required this.warnings});

  final String text;
  final List<SourceAnchor> anchors;
  final List<String> warnings;
}

/// Bounded text-only reader for pre-2007 Word/PowerPoint OLE containers.
///
/// The learning app deliberately does not pretend to preserve layout, masters,
/// notes, charts or embedded objects. Only text that can be traced to the
/// supplied binary source becomes canonical extracted content.
class LegacyOfficeTextExtractor {
  const LegacyOfficeTextExtractor({this.maxRecords = 120000, this.maxDepth = 20, this.maxTextCharacters = 200000});

  final int maxRecords;
  final int maxDepth;
  final int maxTextCharacters;

  ExtractedLegacyOfficeText extract(Uint8List bytes, {required OfficeSourceFormat format}) {
    if (!CfbfFile.isCfbf(bytes)) {
      throw const OfficeTextExtractionException(
        'Legacy Office source is not a valid OLE compound file.',
        kind: OfficeTextExtractionFailureKind.invalidContainer,
      );
    }
    try {
      final file = CfbfFile.fromBytes(bytes);
      return switch (format) {
        OfficeSourceFormat.doc => _extractDoc(file),
        OfficeSourceFormat.ppt => _extractPpt(file),
        OfficeSourceFormat.docx || OfficeSourceFormat.pptx => throw ArgumentError('Expected legacy Office format.'),
      };
    } on OfficeTextExtractionException {
      rethrow;
    } on CfbfException {
      throw const OfficeTextExtractionException(
        'Legacy Office container is corrupt or unsupported.',
        kind: OfficeTextExtractionFailureKind.encryptedOrCorrupt,
      );
    } on RangeError {
      throw const OfficeTextExtractionException(
        'Legacy Office structure is truncated.',
        kind: OfficeTextExtractionFailureKind.encryptedOrCorrupt,
      );
    } catch (_) {
      throw const OfficeTextExtractionException(
        'Legacy Office text could not be extracted safely.',
        kind: OfficeTextExtractionFailureKind.encryptedOrCorrupt,
      );
    }
  }

  ExtractedLegacyOfficeText _extractDoc(CfbfFile file) {
    final document = file.readStream('WordDocument');
    if (document == null || document.length < 0x20) {
      throw const OfficeTextExtractionException(
        'Legacy Word document stream is missing.',
        kind: OfficeTextExtractionFailureKind.invalidContainer,
      );
    }
    final view = ByteData.sublistView(document);
    String text = '';

    if (document.length >= 0x1aa) {
      final flags = view.getUint16(0x0a, Endian.little);
      final table = file.readStream((flags & 0x0200) != 0 ? '1Table' : '0Table');
      final fcClx = view.getUint32(0x01a2, Endian.little);
      final lcbClx = view.getUint32(0x01a6, Endian.little);
      if (table != null && lcbClx > 0 && fcClx >= 0 && fcClx + lcbClx <= table.length) {
        final pieceTable = _pieceTable(Uint8List.sublistView(table, fcClx, fcClx + lcbClx));
        if (pieceTable != null) text = _readWordPieces(pieceTable, document);
      }
    }

    if (text.trim().isEmpty && document.length >= 0x20) {
      final fcMin = view.getUint32(0x18, Endian.little);
      final fcMac = view.getUint32(0x1c, Endian.little);
      if (fcMin < fcMac && fcMin >= 0 && fcMac <= document.length) {
        final slice = Uint8List.sublistView(document, fcMin, fcMac);
        text = _looksUtf16(slice) ? _decodeUtf16(slice) : _decodeAnsi(slice);
      }
    }

    return _compose(_splitParagraphs(text), warning: 'LEGACY_DOC_TEXT_ONLY');
  }

  ExtractedLegacyOfficeText _extractPpt(CfbfFile file) {
    final stream = file.readStream('PowerPoint Document');
    if (stream == null || stream.isEmpty) {
      throw const OfficeTextExtractionException(
        'Legacy PowerPoint stream is missing.',
        kind: OfficeTextExtractionFailureKind.invalidContainer,
      );
    }

    final chunks = <String>[];
    var records = 0;

    void walk(int start, int end, int depth) {
      if (depth > maxDepth) {
        throw const OfficeTextExtractionException(
          'Legacy PowerPoint nesting exceeds the bounded safety limit.',
          kind: OfficeTextExtractionFailureKind.tooLarge,
        );
      }
      final view = ByteData.sublistView(stream);
      var offset = start;
      while (offset + 8 <= end) {
        if (++records > maxRecords) {
          throw const OfficeTextExtractionException(
            'Legacy PowerPoint record count exceeds the bounded safety limit.',
            kind: OfficeTextExtractionFailureKind.tooLarge,
          );
        }
        final versionInstance = view.getUint16(offset, Endian.little);
        final type = view.getUint16(offset + 2, Endian.little);
        final length = view.getUint32(offset + 4, Endian.little);
        final body = offset + 8;
        final bodyEnd = body + length;
        if (bodyEnd < body || bodyEnd > end || bodyEnd > stream.length) {
          throw const OfficeTextExtractionException(
            'Legacy PowerPoint record is truncated.',
            kind: OfficeTextExtractionFailureKind.encryptedOrCorrupt,
          );
        }

        final isContainer = (versionInstance & 0x000f) == 0x000f;
        if (isContainer) {
          if (type != 0x03f8 && type != 0x03f0) walk(body, bodyEnd, depth + 1);
        } else if (type == 0x0fa0) {
          chunks.add(_decodeUtf16(Uint8List.sublistView(stream, body, bodyEnd)));
        } else if (type == 0x0fa8) {
          chunks.add(_decodeAnsi(Uint8List.sublistView(stream, body, bodyEnd)));
        }
        offset = bodyEnd;
      }
    }

    walk(0, stream.length, 0);
    final paragraphs = chunks
        .expand(_splitParagraphs)
        .where((line) => !RegExp(r'^_{2,}PPT\d+$').hasMatch(line))
        .toList(growable: false);
    return _compose(paragraphs, warning: 'LEGACY_PPT_TEXT_ONLY');
  }

  Uint8List? _pieceTable(Uint8List clx) {
    final view = ByteData.sublistView(clx);
    var offset = 0;
    while (offset < clx.length) {
      final marker = clx[offset];
      if (marker == 0x01) {
        if (offset + 3 > clx.length) return null;
        final length = view.getUint16(offset + 1, Endian.little);
        offset += 3 + length;
      } else if (marker == 0x02) {
        if (offset + 5 > clx.length) return null;
        final length = view.getUint32(offset + 1, Endian.little);
        final start = offset + 5;
        if (start + length > clx.length) return null;
        return Uint8List.sublistView(clx, start, start + length);
      } else {
        return null;
      }
    }
    return null;
  }

  String _readWordPieces(Uint8List table, Uint8List document) {
    if (table.length < 16) return '';
    final pieceCount = (table.length - 4) ~/ 12;
    if (pieceCount <= 0) return '';
    final descriptorBase = (pieceCount + 1) * 4;
    if (descriptorBase + pieceCount * 8 > table.length) return '';

    final view = ByteData.sublistView(table);
    final out = StringBuffer();
    for (var index = 0; index < pieceCount; index++) {
      final cpStart = view.getUint32(index * 4, Endian.little);
      final cpEnd = view.getUint32((index + 1) * 4, Endian.little);
      final characterCount = cpEnd - cpStart;
      if (characterCount <= 0) continue;

      final descriptor = descriptorBase + index * 8;
      var fc = view.getUint32(descriptor + 2, Endian.little);
      final compressed = (fc & 0x40000000) != 0;
      fc &= 0x3fffffff;
      if (compressed) {
        final start = fc ~/ 2;
        final end = start + characterCount;
        if (start < 0 || start >= document.length || end > document.length) continue;
        out.write(_decodeAnsi(Uint8List.sublistView(document, start, end)));
      } else {
        final start = fc;
        final end = start + characterCount * 2;
        if (start < 0 || start >= document.length || end > document.length) continue;
        out.write(_decodeUtf16(Uint8List.sublistView(document, start, end)));
      }
      if (out.length > maxTextCharacters) {
        throw const OfficeTextExtractionException(
          'Legacy Word extracted text exceeds the bounded safety limit.',
          kind: OfficeTextExtractionFailureKind.textLimit,
        );
      }
    }
    return out.toString();
  }

  ExtractedLegacyOfficeText _compose(List<String> paragraphs, {required String warning}) {
    final buffer = StringBuffer();
    final anchors = <SourceAnchor>[];
    for (final raw in paragraphs) {
      final paragraph = raw.trim();
      if (paragraph.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write('\n\n');
      final start = buffer.length;
      if (start + paragraph.length > maxTextCharacters) {
        throw const OfficeTextExtractionException(
          'Legacy Office extracted text exceeds the bounded safety limit.',
          kind: OfficeTextExtractionFailureKind.textLimit,
        );
      }
      buffer.write(paragraph);
      anchors.add(SourceAnchor(startOffset: start, endOffset: buffer.length));
    }
    if (buffer.isEmpty) {
      throw const OfficeTextExtractionException(
        'Legacy Office source contains no extractable text.',
        kind: OfficeTextExtractionFailureKind.noExtractableText,
      );
    }
    return ExtractedLegacyOfficeText(text: buffer.toString(), anchors: List.unmodifiable(anchors), warnings: [warning]);
  }

  static List<String> _splitParagraphs(String value) =>
      value.split(RegExp(r'[\r\n\x0b\x0c]+')).map(_clean).where((line) => line.isNotEmpty).toList(growable: false);

  static String _clean(String value) {
    final out = StringBuffer();
    for (final unit in value.codeUnits) {
      if (unit == 0x09) {
        out.write(' ');
      } else if (unit >= 0x20 && unit != 0x7f) {
        out.writeCharCode(unit);
      }
    }
    return out.toString().replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  static bool _looksUtf16(Uint8List bytes) {
    final sample = bytes.length < 80 ? bytes.length : 80;
    if (sample < 4) return false;
    var zeroHighBytes = 0;
    var pairs = 0;
    for (var index = 1; index < sample; index += 2) {
      pairs++;
      if (bytes[index] == 0) zeroHighBytes++;
    }
    return pairs > 0 && zeroHighBytes * 2 >= pairs;
  }

  static String _decodeUtf16(Uint8List bytes) {
    final out = StringBuffer();
    for (var index = 0; index + 1 < bytes.length; index += 2) {
      final unit = bytes[index] | (bytes[index + 1] << 8);
      if (unit != 0) out.writeCharCode(unit);
    }
    return out.toString();
  }

  static String _decodeAnsi(Uint8List bytes) {
    const replacements = <int, int>{
      0x80: 0x20ac,
      0x82: 0x201a,
      0x83: 0x0192,
      0x84: 0x201e,
      0x85: 0x2026,
      0x86: 0x2020,
      0x87: 0x2021,
      0x91: 0x2018,
      0x92: 0x2019,
      0x93: 0x201c,
      0x94: 0x201d,
      0x96: 0x2013,
      0x97: 0x2014,
      0xd0: 0x011e,
      0xdd: 0x0130,
      0xde: 0x015e,
      0xf0: 0x011f,
      0xfd: 0x0131,
      0xfe: 0x015f,
    };
    final out = StringBuffer();
    for (final byte in bytes) {
      if (byte == 0) continue;
      out.writeCharCode(replacements[byte] ?? byte);
    }
    return out.toString();
  }
}
