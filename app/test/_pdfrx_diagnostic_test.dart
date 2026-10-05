import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getTemporaryDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('diagnose direct pdfrx host parsing', () async {
    final bytes = await File('test/fixtures/two_page_text.pdf').readAsBytes();

    try {
      await pdfrxFlutterInitialize();
      debugPrint('PDFRX_DIAGNOSTIC initialization=PASS');
    } catch (error, stackTrace) {
      debugPrint(
        'PDFRX_DIAGNOSTIC initialization=FAIL type=${error.runtimeType} message=$error',
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
        'PDFRX_DIAGNOSTIC openData=FAIL type=${error.runtimeType} message=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      await document?.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 45)));
}
