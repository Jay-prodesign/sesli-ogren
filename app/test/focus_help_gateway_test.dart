import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';
import 'package:sesli_ogren/src/learning/focus_help_gateway.dart';

void main() {
  const source = SourceVersionIdentity(
    materialId: MaterialId('material-a'),
    sourceVersionId: SourceVersionId('source-v1'),
    contentDigest: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    trustClass: SourceTrustClass.userProvided,
  );

  test('Focus help accepts only exact current source identity', () {
    const ready = FocusHelpReady(
      sourceVersionId: SourceVersionId('source-v1'),
      sourceContentDigest: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      text: 'Grounded help',
      executionRef: 'exec-1',
    );
    expect(ready.matches(source), isTrue);
    expect(
      const FocusHelpReady(
        sourceVersionId: SourceVersionId('source-v1'),
        sourceContentDigest: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        text: 'stale',
        executionRef: 'exec-2',
      ).matches(source),
      isFalse,
    );
  });

  test('production default Focus help fails closed', () async {
    final result = await const UnavailableFocusHelpGateway().help(
      const FocusHelpRequest(
        materialId: MaterialId('material-a'),
        sourceVersionId: SourceVersionId('source-v1'),
        sourceContentDigest: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        kind: FocusHelpKind.hint,
        outputLocale: 'tr-TR',
      ),
    );
    expect(result, isA<FocusHelpUnavailable>());
  });
}
