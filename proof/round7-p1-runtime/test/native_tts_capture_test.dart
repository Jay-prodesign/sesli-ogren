import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:r7_p1_runtime_proof/src/native_tts_capture.dart';

Map<String, String> completeCorpus() {
  return <String, String>{
    for (final item in 'ABCDEFGHIJKL'.split('')) item: 'Synthetic benchmark item $item',
  };
}

void main() {
  test('accepts an exact non-empty A-L corpus', () {
    final corpus = completeCorpus();
    expect(parseCanonicalCorpus(jsonEncode(corpus)), corpus);
  });

  test('rejects a missing canonical item', () {
    final corpus = completeCorpus()..remove('L');
    expect(() => parseCanonicalCorpus(jsonEncode(corpus)), throwsFormatException);
  });

  test('rejects an extra canonical item', () {
    final corpus = completeCorpus()..['M'] = 'extra';
    expect(() => parseCanonicalCorpus(jsonEncode(corpus)), throwsFormatException);
  });

  test('rejects blank canonical text', () {
    final corpus = completeCorpus()..['K'] = '   ';
    expect(() => parseCanonicalCorpus(jsonEncode(corpus)), throwsFormatException);
  });
}
