import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_engine/quds_office_engine.dart' show CfbfWriter;
import 'package:sesli_ogren/src/data/office_text_extractor.dart';

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  const extractor = OpenXmlOfficeTextExtractor();

  test('DOCX extraction preserves paragraph order and bounded anchors', () async {
    final bytes = _zip({
      '[Content_Types].xml': '<Types/>',
      'word/document.xml': '''
<w:document xmlns:w="urn:word">
  <w:body>
    <w:p><w:r><w:t>Fotosentez ışık enerjisini dönüştürür.</w:t></w:r></w:p>
    <w:p><w:r><w:t>Klorofil ışığın yakalanmasına yardım eder.</w:t></w:r></w:p>
  </w:body>
</w:document>
''',
    });
    final result = await extractor.extract(bytes, sourceName: 'biyoloji.docx');

    expect(result.format, OfficeSourceFormat.docx);
    expect(result.text, 'Fotosentez ışık enerjisini dönüştürür.\n\nKlorofil ışığın yakalanmasına yardım eder.');
    expect(result.anchors, hasLength(2));
    expect(
      result.text.substring(result.anchors.first.startOffset, result.anchors.first.endOffset),
      startsWith('Fotosentez'),
    );
    expect(result.warnings, contains('DOCX_LAYOUT_NOT_PRESERVED'));
  });

  test('PPTX extraction preserves slide order and slide-number anchors', () async {
    final bytes = _zip({
      '[Content_Types].xml': '<Types/>',
      'ppt/slides/slide2.xml':
          '<p:sld xmlns:p="urn:p" xmlns:a="urn:a"><p:cSld><a:t>İkinci slayt</a:t></p:cSld></p:sld>',
      'ppt/slides/slide1.xml':
          '<p:sld xmlns:p="urn:p" xmlns:a="urn:a"><p:cSld><a:t>Birinci</a:t><a:t>slayt</a:t></p:cSld></p:sld>',
    });
    final result = await extractor.extract(bytes, sourceName: 'ders.pptx');

    expect(result.format, OfficeSourceFormat.pptx);
    expect(result.text, 'Birinci\nslayt\n\nİkinci slayt');
    expect(result.anchors.map((anchor) => anchor.pageNumber), [1, 2]);
    expect(result.warnings, contains('PPTX_SLIDE_TEXT_ONLY'));
  });

  test('legacy DOC dispatches through the bounded OLE extractor', () async {
    final word = Uint8List(512);
    const text = 'Fotosentez ışık enerjisini dönüştürür.\rKlorofil ışığı yakalar.';
    final encoded = Uint8List.fromList(text.codeUnits);
    const start = 0x100;
    word.setRange(start, start + encoded.length, encoded);
    final view = ByteData.sublistView(word);
    view.setUint32(0x18, start, Endian.little);
    view.setUint32(0x1c, start + encoded.length, Endian.little);
    final bytes = (CfbfWriter()..addStream('WordDocument', word)).build();

    final result = await extractor.extract(bytes, sourceName: 'old.doc');

    expect(result.format, OfficeSourceFormat.doc);
    expect(result.text, contains('Fotosentez'));
    expect(result.text, contains('Klorofil'));
    expect(result.warnings, contains('LEGACY_DOC_TEXT_ONLY'));
  });
}
