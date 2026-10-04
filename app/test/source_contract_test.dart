import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';

void main() {
  test('source identity separates user source from AI interpretation', () {
    const source = SourceVersionIdentity(
      materialId: MaterialId('material-1'),
      sourceVersionId: SourceVersionId('version-1'),
      contentDigest: 'sha256:abc',
      trustClass: SourceTrustClass.userProvided,
    );

    expect(source.trustClass, SourceTrustClass.userProvided);
    expect(source.contentDigest, 'sha256:abc');
  });
}
