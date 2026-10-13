import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/grounded_tutor.dart';
import '../domain/learning_contracts.dart';

class GroundedTutorException implements Exception {
  const GroundedTutorException(this.message);
  final String message;

  @override
  String toString() => 'GroundedTutorException: $message';
}

class GroundedTutorService {
  GroundedTutorService({required this.store, DateTime Function()? now}) : _now = now ?? DateTime.now;

  final SqliteSourceStore store;
  final DateTime Function() _now;

  Future<GroundedTutorThreadState> openThread({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    SourceVersionId? expectedSourceVersionId,
    SourceAnchor? contextAnchor,
  }) async {
    final source = await store.currentSourceVersion(learner: learner, materialId: materialId);
    if (source == null || !source.isCurrent) {
      throw const GroundedTutorException('Güncel kaynak bulunamadı.');
    }
    if (expectedSourceVersionId != null && source.identity.sourceVersionId != expectedSourceVersionId) {
      throw const GroundedTutorException('Kaynak değişti. Tutor eski kaynak bağlamını yeni sürüme taşımadı.');
    }
    final extracted = await store.extractedContentForSource(
      learner: learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid || extracted.sourceContentDigest != source.identity.contentDigest) {
      throw const GroundedTutorException('Tutor için güvenilir güncel kaynak metni bulunamadı.');
    }
    if (contextAnchor != null && !_anchorIsValid(contextAnchor, extracted.normalizedText)) {
      throw const GroundedTutorException('Seçili kaynak bölümü artık güncel değil.');
    }
    final thread = await store.openGroundedTutorThread(
      learner: learner,
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      contextAnchor: contextAnchor,
      openedAt: _now().toUtc(),
    );
    final turns = await store.groundedTutorTurns(learner: learner, threadId: thread.id);
    return GroundedTutorThreadState(thread: thread, turns: turns);
  }

  Future<GroundedTutorThreadState> ask({
    required AuthenticatedLearner learner,
    required GroundedTutorThreadId threadId,
    required String question,
  }) async {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty || normalizedQuestion.length > 2000) {
      throw const GroundedTutorException('Soru 1–2000 karakter arasında olmalı.');
    }
    final thread = await store.groundedTutorThread(learner: learner, threadId: threadId);
    if (thread == null) {
      throw const GroundedTutorException('Bu Tutor konuşması eski bir kaynak sürümüne ait.');
    }
    final source = await store.currentSourceVersion(learner: learner, materialId: thread.materialId);
    if (source == null || source.identity.sourceVersionId != thread.sourceVersionId) {
      throw const GroundedTutorException('Kaynak değişti. Eski konuşma yeni kaynağa taşınmadı.');
    }
    final extracted = await store.extractedContentForSource(
      learner: learner,
      sourceVersionId: thread.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid || extracted.sourceContentDigest != source.identity.contentDigest) {
      throw const GroundedTutorException('Tutor güncel kaynak metnini doğrulayamadı.');
    }

    final questionTurn = await store.saveGroundedTutorTurn(
      learner: learner,
      threadId: thread.id,
      role: GroundedTutorTurnRole.learner,
      text: normalizedQuestion,
      supportState: GroundedTutorSupportState.learnerQuestion,
      createdAt: _now().toUtc(),
    );

    final answer = GroundedTutorPolicy.answer(
      question: normalizedQuestion,
      sourceText: extracted.normalizedText,
      contextAnchor: thread.contextAnchor,
      sourceAnchors: extracted.anchors,
    );

    final sourceAfterAnswer = await store.currentSourceVersion(learner: learner, materialId: thread.materialId);
    if (sourceAfterAnswer?.identity.sourceVersionId != thread.sourceVersionId) {
      throw const GroundedTutorException('Kaynak soru sırasında değişti. Yanıt kaydedilmedi.');
    }

    await store.saveGroundedTutorTurn(
      learner: learner,
      threadId: thread.id,
      role: GroundedTutorTurnRole.tutor,
      text: answer.text,
      supportState: answer.supportState,
      sourceAnchor: answer.sourceAnchor,
      sourceExcerpt: answer.sourceExcerpt,
      createdAt: _now().toUtc().add(const Duration(microseconds: 1)),
    );

    final refreshedThread = await store.groundedTutorThread(learner: learner, threadId: thread.id);
    if (refreshedThread == null) {
      throw const GroundedTutorException('Tutor konuşması artık güncel değil.');
    }
    final turns = await store.groundedTutorTurns(learner: learner, threadId: thread.id);
    if (!turns.any((turn) => turn.id == questionTurn.id)) {
      throw const GroundedTutorException('Soru yerel konuşma kaydına yazılamadı.');
    }
    return GroundedTutorThreadState(thread: refreshedThread, turns: turns);
  }

  static bool _anchorIsValid(SourceAnchor anchor, String sourceText) =>
      anchor.startOffset >= 0 && anchor.endOffset > anchor.startOffset && anchor.endOffset <= sourceText.length;
}

class GroundedTutorAnswer {
  const GroundedTutorAnswer({
    required this.text,
    required this.supportState,
    required this.sourceAnchor,
    required this.sourceExcerpt,
  });

  final String text;
  final GroundedTutorSupportState supportState;
  final SourceAnchor? sourceAnchor;
  final String? sourceExcerpt;
}

abstract final class GroundedTutorPolicy {
  static GroundedTutorAnswer answer({
    required String question,
    required String sourceText,
    required List<SourceAnchor> sourceAnchors,
    SourceAnchor? contextAnchor,
  }) {
    if (contextAnchor != null) {
      final excerpt = sourceText.substring(contextAnchor.startOffset, contextAnchor.endOffset).trim();
      if (excerpt.isNotEmpty) {
        return GroundedTutorAnswer(
          text:
              'Seçtiğin bölüm bu soruya doğrudan kaynak dayanağı sağlıyor. '
              'Kaynağın söylediği kısmı aşağıda aynen gösteriyorum; bunun ötesinde yeni bir iddia eklemiyorum.',
          supportState: GroundedTutorSupportState.sourceSupported,
          sourceAnchor: contextAnchor,
          sourceExcerpt: excerpt,
        );
      }
    }

    final questionTerms = _terms(question);
    if (questionTerms.isEmpty) return _unsupported();
    _SentenceCandidate? best;
    for (final match in RegExp(r'[^.!?\n]+[.!?]?').allMatches(sourceText)) {
      final raw = match.group(0)!;
      final leading = raw.length - raw.trimLeft().length;
      final sentence = raw.trim();
      if (sentence.length < 12) continue;
      final start = match.start + leading;
      final end = start + sentence.length;
      final sentenceTerms = _terms(sentence);
      final overlap = questionTerms.where(sentenceTerms.contains).length;
      if (overlap == 0) continue;
      final score = overlap * 100 - sentence.length.clamp(0, 500);
      final page = _pageFor(start, end, sourceAnchors);
      final candidate = _SentenceCandidate(
        text: sentence,
        anchor: SourceAnchor(startOffset: start, endOffset: end, pageNumber: page),
        score: score,
      );
      if (best == null || candidate.score > best.score) best = candidate;
    }
    if (best == null) return _unsupported();
    return GroundedTutorAnswer(
      text:
          'Güncel kaynakta soruna en doğrudan dayanak olan bölüm bu. '
          'Yanıtı bu ifadeyle sınırlı tutuyorum; kaynakta açıkça bulunmayan bir sonucu eklemiyorum.',
      supportState: GroundedTutorSupportState.sourceSupported,
      sourceAnchor: best.anchor,
      sourceExcerpt: best.text,
    );
  }

  static GroundedTutorAnswer _unsupported() => const GroundedTutorAnswer(
    text:
        'Bu soruya güncel kaynakta yeterli dayanak bulamadım. '
        'Kaynağın başka bir bölümünü seçebilir ya da soruyu kaynakta geçen kavramlarla yeniden sorabilirsin.',
    supportState: GroundedTutorSupportState.sourceUnsupported,
    sourceAnchor: null,
    sourceExcerpt: null,
  );

  static Set<String> _terms(String value) {
    final normalized = value.toLowerCase().replaceAll('İ', 'i').replaceAll('I', 'ı');
    return RegExp(r'[a-zçğıöşü0-9]+')
        .allMatches(normalized)
        .map((match) => match.group(0)!)
        .where((word) => word.length >= 3 && !_stopWords.contains(word))
        .toSet();
  }

  static int? _pageFor(int start, int end, List<SourceAnchor> anchors) {
    for (final anchor in anchors) {
      if (start >= anchor.startOffset && end <= anchor.endOffset) return anchor.pageNumber;
    }
    return null;
  }

  static const _stopWords = <String>{
    'acaba',
    'ama',
    'bana',
    'ben',
    'bir',
    'bunu',
    'bu',
    'da',
    'daha',
    'de',
    'diye',
    'gibi',
    'için',
    'ile',
    'mı',
    'mi',
    'mu',
    'mü',
    'nasıl',
    'ne',
    'neden',
    'nedir',
    'olan',
    'olarak',
    'şu',
    've',
    'veya',
  };
}

class _SentenceCandidate {
  const _SentenceCandidate({required this.text, required this.anchor, required this.score});
  final String text;
  final SourceAnchor anchor;
  final int score;
}
