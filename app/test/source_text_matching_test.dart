import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/source_text_matching.dart';

void main() {
  test('finds Turkish source evidence without changing original source offsets', () {
    const source = 'Klorofil ışık enerjisini kullanır. Işık enerjisi dönüşür.';

    final chlorophyll = findFirstTurkishSourceTextMatch(source, 'KLOROFİL');
    expect(chlorophyll, isNotNull);
    expect(source.substring(chlorophyll!.start, chlorophyll.end), 'Klorofil');

    final light = findTurkishSourceTextMatches(source, 'ışık');
    expect(light, hasLength(2));
    expect(source.substring(light.first.start, light.first.end), 'ışık');
    expect(source.substring(light.last.start, light.last.end), 'Işık');
  });

  test('returns no evidence span when the answer is not literally in the source', () {
    const source = 'Klorofil ışık enerjisinin yakalanmasına yardım eder.';
    expect(findFirstTurkishSourceTextMatch(source, 'mitokondri'), isNull);
  });
}
