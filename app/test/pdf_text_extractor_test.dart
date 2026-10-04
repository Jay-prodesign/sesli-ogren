import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sesli_ogren/src/data/pdf_text_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();

  test('real two-page PDF extracts text with page provenance anchors', () async {
    final bytes = await File('test/fixtures/two_page_text.pdf').readAsBytes();
    final result = await const PdfrxPdfTextExtractor().extract(
      bytes,
      sourceName: 'two_page_text.pdf',
    );

    expect(result.pageCount, 2);
    expect(result.text, contains('Learning evidence page one'));
    expect(result.text, contains('Second page keeps provenance'));
    expect(result.anchors.map((anchor) => anchor.pageNumber), [1, 2]);
    expect(
      result.text.substring(
        result.anchors.first.startOffset,
        result.anchors.first.endOffset,
      ),
      contains('Learning evidence page one'),
    );
  });
}
