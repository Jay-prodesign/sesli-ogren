import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/domain/learning_contracts.dart';

void main() {
  test('source identity keeps trust and knowledge authority explicit', () {
    const source = SourceVersionIdentity(
      materialId: MaterialId('material-1'),
      sourceVersionId: SourceVersionId('version-1'),
      contentDigest: 'abc',
      trustClass: SourceTrustClass.userProvided,
      knowledgeClass: SourceKnowledgeClass.learnerOwned,
    );

    expect(source.trustClass, SourceTrustClass.userProvided);
    expect(source.knowledgeClass, SourceKnowledgeClass.learnerOwned);
    expect(source.contentDigest, 'abc');
  });
}
