import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagnose direct pdfrx host parsing', () async {
    final bytes = await File('test/fixtures/two_page_text.pdf').readAsBytes();

    try {
      await pdfrxFlutterInitialize();
      debugPrint('PDFRX_DIAGNOSTIC initialization=PASS');
    } catch (error, stackTrace) {
      debugPrint(
        'PDFRX_DIAGNOSTIC initialization=FAIL '
        'type=${error.runtimeType} message=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    PdfDocument? document;
    try {
      document = await PdfDocument.openData(
        bytes,
        sourceName: 'two_page_text.pdf',
      );
      debugPrint(
        'PDFRX_DIAGNOSTIC openData=PASS pages=${document.pages.length}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'PDFRX_DIAGNOSTIC openData=FAIL '
        'type=${error.runtimeType} message=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      await document?.dispose();
    }
  });
}
