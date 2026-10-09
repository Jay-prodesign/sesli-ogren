import '../domain/learning_contracts.dart';

enum FocusHelpKind { hint, directExplanation }

class FocusHelpRequest {
  const FocusHelpRequest({
    required this.materialId,
    required this.sourceVersionId,
    required this.sourceContentDigest,
    required this.kind,
    required this.outputLocale,
    this.learnerQuestion,
    this.serverMaterialId,
    this.groundingContentHash,
  });
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final String sourceContentDigest;
  final FocusHelpKind kind;
  final String outputLocale;
  final String? learnerQuestion;

  /// Server UUID bound to the exact current local source version.
  final String? serverMaterialId;

  /// SHA-256 of the normalized text mirrored to the server.
  final String? groundingContentHash;
}

sealed class FocusHelpResult {
  const FocusHelpResult();
}

class FocusHelpReady extends FocusHelpResult {
  const FocusHelpReady({
    required this.sourceVersionId,
    required this.sourceContentDigest,
    required this.text,
    required this.executionRef,
    this.sourceCues = const <String>[],
  });
  final SourceVersionId sourceVersionId;
  final String sourceContentDigest;
  final String text;
  final String executionRef;
  final List<String> sourceCues;

  bool matches(SourceVersionIdentity source) =>
      sourceVersionId == source.sourceVersionId && sourceContentDigest == source.contentDigest;
}

class FocusHelpUnavailable extends FocusHelpResult {
  const FocusHelpUnavailable(this.reason);
  final String reason;
}

abstract interface class FocusHelpGateway {
  Future<FocusHelpResult> help(FocusHelpRequest request);
}

class UnavailableFocusHelpGateway implements FocusHelpGateway {
  const UnavailableFocusHelpGateway();

  @override
  Future<FocusHelpResult> help(FocusHelpRequest request) async =>
      const FocusHelpUnavailable('Kaynağa bağlı etkileşimli yardım servisi henüz etkin değil.');
}
