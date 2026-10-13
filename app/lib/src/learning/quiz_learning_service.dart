import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/sqlite_source_store.dart';
import '../domain/authenticated_learner.dart';
import '../domain/learning_contracts.dart';
import '../domain/quiz_learning.dart';

class QuizLearningException implements Exception {
  const QuizLearningException(this.message);

  final String message;

  @override
  String toString() => 'QuizLearningException: $message';
}

class QuizLearningService {
  const QuizLearningService({required this.store, DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const generationVersion = 'quiz-cloze-v1-source-options';
  static const maxQuestions = 5;
  static const maxOptions = 4;

  final SqliteSourceStore store;
  final DateTime Function() _now;

  Future<QuizStudyState> openCurrentSet({required AuthenticatedLearner learner, required MaterialId materialId}) async {
    final source = await store.currentSourceVersion(learner: learner, materialId: materialId);
    if (source == null) {
      throw const QuizLearningException('Quiz için güncel bir kaynak bulunamadı.');
    }
    final extracted = await store.extractedContentForSource(
      learner: learner,
      sourceVersionId: source.identity.sourceVersionId,
    );
    if (extracted == null || !extracted.isValid || extracted.normalizedText.trim().isEmpty) {
      throw const QuizLearningException('Güncel kaynak quiz üretmek için okunabilir metin içermiyor.');
    }

    var set = await store.quizSet(
      learner: learner,
      materialId: materialId,
      sourceVersionId: source.identity.sourceVersionId,
      generationVersion: generationVersion,
    );
    if (set == null) {
      final candidate = _buildSet(
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
        extracted: extracted,
        createdAt: _now().toUtc(),
      );
      await store.saveQuizSet(learner: learner, set: candidate);
      set = await store.quizSet(
        learner: learner,
        materialId: materialId,
        sourceVersionId: source.identity.sourceVersionId,
        generationVersion: generationVersion,
      );
    }
    if (set == null || set.questions.isEmpty) {
      throw const QuizLearningException('Bu kaynak için güvenilir quiz soruları oluşturulamadı.');
    }

    final reviews = await store.quizReviews(learner: learner, setId: set.id);
    final session = await store.quizSession(learner: learner, setId: set.id);
    return QuizStudyState(
      set: set,
      reviews: {for (final review in reviews) review.questionId: review},
      session: session ?? QuizSessionState.initial(set.id),
    );
  }

  Future<QuizStudyState> recordAnswer({
    required AuthenticatedLearner learner,
    required MaterialId materialId,
    required QuizSetId setId,
    required QuizQuestionId questionId,
    required QuizAnswerKind kind,
    int? selectedOptionIndex,
  }) async {
    final state = await openCurrentSet(learner: learner, materialId: materialId);
    if (state.set.id != setId) {
      throw const QuizLearningException('Quiz seti güncel kaynakla eşleşmiyor.');
    }
    final question = state.currentQuestion;
    if (question == null || question.id != questionId) {
      throw const QuizLearningException('Quiz yanıtı aktif soruyla eşleşmiyor.');
    }
    if (kind == QuizAnswerKind.selected) {
      if (selectedOptionIndex == null || selectedOptionIndex < 0 || selectedOptionIndex >= question.options.length) {
        throw const QuizLearningException('Seçilen quiz yanıtı geçerli değil.');
      }
    } else if (selectedOptionIndex != null) {
      throw const QuizLearningException('Bilmiyorum yanıtı bir seçenek taşıyamaz.');
    }

    final committed = await store.recordQuizAnswer(
      learner: learner,
      set: state.set,
      question: question,
      kind: kind,
      selectedOptionIndex: selectedOptionIndex,
      answeredAt: _now().toUtc(),
    );
    return QuizStudyState(
      set: state.set,
      reviews: {...state.reviews, committed.review.questionId: committed.review},
      session: committed.session,
    );
  }

  Future<QuizStudyState> restartSession({required AuthenticatedLearner learner, required MaterialId materialId}) async {
    final state = await openCurrentSet(learner: learner, materialId: materialId);
    final session = await store.resetQuizSession(learner: learner, set: state.set, updatedAt: _now().toUtc());
    return QuizStudyState(set: state.set, reviews: state.reviews, session: session);
  }

  QuizSetRecord _buildSet({
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required ExtractedContentRecord extracted,
    required DateTime createdAt,
  }) {
    final candidates = _findCandidates(extracted);
    if (candidates.length < 3) {
      throw const QuizLearningException('Kaynak, quiz seçenekleri için yeterli farklı kavram içermiyor.');
    }
    final setDigest = sha256.convert(utf8.encode('${sourceVersionId.value}\u0000$generationVersion')).toString();
    final setId = QuizSetId('qzs_${setDigest.substring(0, 32)}');
    final questionCount = candidates.length < maxQuestions ? candidates.length : maxQuestions;
    final answers = candidates.take(questionCount).map((candidate) => candidate.answer).toList(growable: false);

    final questions = <QuizQuestionRecord>[];
    for (var index = 0; index < questionCount; index++) {
      final candidate = candidates[index];
      final optionCount = answers.length < maxOptions ? answers.length : maxOptions;
      final baseOptions = <String>[candidate.answer];
      for (var offset = 1; baseOptions.length < optionCount; offset++) {
        final answer = answers[(index + offset) % answers.length];
        if (!baseOptions.contains(answer)) baseOptions.add(answer);
      }
      final shift = index % baseOptions.length;
      final options = <String>[...baseOptions.skip(shift), ...baseOptions.take(shift)];
      final correctOptionIndex = options.indexOf(candidate.answer);
      final questionDigest = sha256
          .convert(
            utf8.encode(
              '${setId.value}\u0000${candidate.sentenceStart}\u0000'
              '${candidate.wordStartInSentence}\u0000${candidate.answer.toLowerCase()}',
            ),
          )
          .toString();
      questions.add(
        QuizQuestionRecord(
          id: QuizQuestionId('qzq_${questionDigest.substring(0, 32)}'),
          setId: setId,
          ordinal: questions.length,
          prompt: candidate.sentence.replaceRange(candidate.wordStartInSentence, candidate.wordEndInSentence, '_____'),
          options: options,
          correctOptionIndex: correctOptionIndex,
          sourceAnchor: SourceAnchor(
            startOffset: candidate.sentenceStart,
            endOffset: candidate.sentenceEnd,
            pageNumber: candidate.pageNumber,
          ),
          sourceExcerpt: candidate.sentence,
        ),
      );
    }

    return QuizSetRecord(
      id: setId,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      generationVersion: generationVersion,
      createdAt: createdAt,
      questions: questions,
    );
  }

  static List<_QuizCandidate> _findCandidates(ExtractedContentRecord extracted) {
    final candidates = <_QuizCandidate>[];
    final usedAnswers = <String>{};

    for (final sentenceMatch in RegExp(r'[^.!?\n]+[.!?]?').allMatches(extracted.normalizedText)) {
      final rawSentence = sentenceMatch.group(0)!;
      final leftTrimmed = rawSentence.trimLeft();
      final sentence = leftTrimmed.trimRight();
      if (sentence.length < 24 || sentence.length > 320) continue;

      final leadingWhitespace = rawSentence.length - leftTrimmed.length;
      final sentenceStart = sentenceMatch.start + leadingWhitespace;
      final words = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]+').allMatches(sentence).where((match) {
        final word = match.group(0)!;
        final normalized = _normalize(word);
        return word.length >= 5 && !_stopWords.contains(normalized);
      }).toList();
      if (words.isEmpty) continue;

      final selected = words.first;
      final answer = selected.group(0)!;
      if (!usedAnswers.add(_normalize(answer))) continue;

      int? pageNumber;
      for (final anchor in extracted.anchors) {
        if (sentenceStart >= anchor.startOffset && sentenceStart < anchor.endOffset) {
          pageNumber = anchor.pageNumber;
          break;
        }
      }

      candidates.add(
        _QuizCandidate(
          sentence: sentence,
          sentenceStart: sentenceStart,
          sentenceEnd: sentenceStart + sentence.length,
          wordStartInSentence: selected.start,
          wordEndInSentence: selected.end,
          answer: answer,
          pageNumber: pageNumber,
        ),
      );
      if (candidates.length >= maxQuestions) break;
    }
    return candidates;
  }

  static String _normalize(String value) => value.toLowerCase().replaceAll('İ', 'i').replaceAll('I', 'ı');

  static const _stopWords = <String>{
    'ancak',
    'artık',
    'bazen',
    'bunun',
    'çünkü',
    'daha',
    'diğer',
    'doğru',
    'göre',
    'hangi',
    'içinde',
    'kadar',
    'olan',
    'olarak',
    'olduğu',
    'önce',
    'sonra',
    'şekilde',
    'tarafından',
    'üzerinde',
    'vardır',
    'veya',
    'there',
    'which',
    'while',
    'where',
    'their',
    'about',
  };
}

class _QuizCandidate {
  const _QuizCandidate({
    required this.sentence,
    required this.sentenceStart,
    required this.sentenceEnd,
    required this.wordStartInSentence,
    required this.wordEndInSentence,
    required this.answer,
    required this.pageNumber,
  });

  final String sentence;
  final int sentenceStart;
  final int sentenceEnd;
  final int wordStartInSentence;
  final int wordEndInSentence;
  final String answer;
  final int? pageNumber;
}
