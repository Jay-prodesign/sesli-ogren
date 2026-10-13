import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_engine/quds_office_engine.dart' show CfbfWriter;
import 'package:sesli_ogren/src/data/legacy_office_text_extractor.dart';
import 'package:sesli_ogren/src/data/office_text_extractor.dart';

void _writeU16(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint16(offset, value, Endian.little);
}

void _writeU32(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint32(offset, value, Endian.little);
}

void main() {
  const extractor = LegacyOfficeTextExtractor();

  test('legacy DOC fallback extracts bounded contiguous source text', () {
    final word = Uint8List(512);
    const text = 'Fotosentez ışık enerjisini dönüştürür.\rKlorofil ışığı yakalar.';
    final encoded = Uint8List.fromList(text.codeUnits);
    const start = 0x100;
    word.setRange(start, start + encoded.length, encoded);
    _writeU32(word, 0x18, start);
    _writeU32(word, 0x1c, start + encoded.length);

    final writer = CfbfWriter()..addStream('WordDocument', word);
    final result = extractor.extract(writer.build(), format: OfficeSourceFormat.doc);

    expect(result.text, contains('Fotosentez'));
    expect(result.text, contains('Klorofil'));
    expect(result.anchors, hasLength(2));
    expect(result.warnings, contains('LEGACY_DOC_TEXT_ONLY'));
  });

  test('legacy PPT reads visible text atoms but skips notes containers', () {
    Uint8List record(int version, int type, Uint8List body) {
      final bytes = Uint8List(8 + body.length);
      _writeU16(bytes, 0, version);
      _writeU16(bytes, 2, type);
      _writeU32(bytes, 4, body.length);
      bytes.setRange(8, bytes.length, body);
      return bytes;
    }

    Uint8List utf16(String value) {
      final bytes = Uint8List(value.length * 2);
      final view = ByteData.sublistView(bytes);
      for (var i = 0; i < value.length; i++) {
        view.setUint16(i * 2, value.codeUnitAt(i), Endian.little);
      }
      return bytes;
    }

    final visible = record(0, 0x0fa0, utf16('Birinci slayt'));
    final hiddenNote = record(0, 0x0fa0, utf16('Gizli konuşmacı notu'));
    final notesContainer = record(0x000f, 0x03f0, hiddenNote);
    final stream = Uint8List(visible.length + notesContainer.length)
      ..setRange(0, visible.length, visible)
      ..setRange(visible.length, visible.length + notesContainer.length, notesContainer);

    final writer = CfbfWriter()..addStream('PowerPoint Document', stream);
    final result = extractor.extract(writer.build(), format: OfficeSourceFormat.ppt);

    expect(result.text, contains('Birinci slayt'));
    expect(result.text, isNot(contains('Gizli konuşmacı notu')));
    expect(result.warnings, contains('LEGACY_PPT_TEXT_ONLY'));
  });
}
