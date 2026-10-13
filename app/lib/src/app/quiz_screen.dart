import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/learning_contracts.dart';
import '../domain/quiz_learning.dart';
import '../learning/quiz_learning_service.dart';
import 'app_runtime.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    required this.runtime,
    required this.materialId,
    this.scheduledReviewSourceVersionId,
    this.scheduledReviewSourceAnchor,
    super.key,
  }) : assert(
         (scheduledReviewSourceVersionId == null) == (scheduledReviewSourceAnchor == null),
         'Scheduled quiz review requires both source version and source anchor.',
       );

  final AppRuntime runtime;
  final MaterialId materialId;
  final SourceVersionId? scheduledReviewSourceVersionId;
  final SourceAnchor? scheduledReviewSourceAnchor;

  bool get isScheduledReview => scheduledReviewSourceVersionId != null;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<_QuizViewData> _future;
  _QuizViewData? _data;
  int? _selectedOptionIndex;
  _QuizFeedback? _feedback;
  bool _busy = false;
  String? _recoveryNotice;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_QuizViewData> _load() async {
    final material = await widget.runtime.store.material(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (material == null || !material.isActive) {
      throw const QuizLearningException('Materyal artık kullanılamıyor.');
    }
    final study = widget.isScheduledReview
        ? await widget.runtime.quiz.startScheduledReview(
            learner: widget.runtime.learner,
            materialId: widget.materialId,
            sourceVersionId: widget.scheduledReviewSourceVersionId!,
            sourceAnchor: widget.scheduledReviewSourceAnchor!,
          )
        : await widget.runtime.quiz.openCurrentSet(learner: widget.runtime.learner, materialId: widget.materialId);
    final source = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: widget.materialId,
    );
    if (source == null || source.identity.sourceVersionId != study.set.sourceVersionId) {
      throw const QuizLearningException('Quiz güncel kaynak sürümüyle eşleşmiyor.');
    }
    return _QuizViewData(material: material, source: source, study: study);
  }

  void _reload() {
    setState(() {
      _data = null;
      _selectedOptionIndex = null;
      _feedback = null;
      _busy = false;
      _recoveryNotice = null;
      _future = _load();
    });
  }

  void _feedbackHaptic({required bool strong}) {
    final media = MediaQuery.maybeOf(context);
    if ((media?.disableAnimations ?? false) || (media?.accessibleNavigation ?? false)) return;
    try {
      if (strong) {
        unawaited(HapticFeedback.mediumImpact().catchError((_) {}));
      } else {
        unawaited(HapticFeedback.selectionClick().catchError((_) {}));
      }
    } catch (_) {
      // Haptics acknowledge interaction only and must never block learning.
    }
  }

  void _selectOption(int index) {
    if (_busy || _feedback != null) return;
    _feedbackHaptic(strong: false);
    setState(() => _selectedOptionIndex = index);
  }

  Future<void> _commit({required QuizAnswerKind kind}) async {
    final data = _data;
    final question = data?.study.currentQuestion;
    if (data == null || question == null || _busy || _feedback != null) return;
    final selected = kind == QuizAnswerKind.selected ? _selectedOptionIndex : null;
    if (kind == QuizAnswerKind.selected && selected == null) return;

    setState(() {
      _busy = true;
      _recoveryNotice = null;
    });
    try {
      final next = await widget.runtime.quiz.recordAnswer(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
        setId: data.study.set.id,
        questionId: question.id,
        kind: kind,
        selectedOptionIndex: selected,
      );
      if (!mounted) return;
      final review = next.reviews[question.id];
      if (review == null) {
        throw const QuizLearningException('Quiz yanıtı kaydedildi ancak sonucu okunamadı.');
      }
      _feedbackHaptic(strong: review.lastIsCorrect == true);
      setState(() {
        _data = _QuizViewData(material: data.material, source: data.source, study: next);
        _feedback = _QuizFeedback(question: question, review: review);
        _selectedOptionIndex = null;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _selectedOptionIndex = null;
        _feedback = null;
        _busy = false;
        _recoveryNotice = 'Önceki quiz yanıtı kaydedilmedi. Güncel kaynaktan devam ediyorsun.';
        _future = _load();
      });
    }
  }

  void _continueAfterFeedback() {
    if (_busy || _feedback == null) return;
    _feedbackHaptic(strong: false);
    if (widget.isScheduledReview && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _feedback = null);
  }

  Future<void> _restart() async {
    final data = _data;
    if (data == null || _busy) return;
    setState(() => _busy = true);
    try {
      final next = await widget.runtime.quiz.restartSession(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (!mounted) return;
      _feedbackHaptic(strong: false);
      setState(() {
        _data = _QuizViewData(material: data.material, source: data.source, study: next);
        _selectedOptionIndex = null;
        _feedback = null;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Quiz turu yeniden başlatılamadı. Tekrar deneyebilirsin.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_QuizViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (_data == null && snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          _data = snapshot.data;
        }
        if (_data == null && snapshot.connectionState == ConnectionState.done && snapshot.hasError) {
          return _QuizError(onRetry: _reload);
        }
        final data = _data;
        if (data == null) return const _QuizLoading();
        return _QuizStudyView(
          data: data,
          selectedOptionIndex: _selectedOptionIndex,
          feedback: _feedback,
          busy: _busy,
          recoveryNotice: _recoveryNotice,
          scheduledReview: widget.isScheduledReview,
          onSelect: _selectOption,
          onSubmit: () => _commit(kind: QuizAnswerKind.selected),
          onUnknown: () => _commit(kind: QuizAnswerKind.unknown),
          onContinue: _continueAfterFeedback,
          onRestart: _restart,
        );
      },
    );
  }
}

class _QuizViewData {
  const _QuizViewData({required this.material, required this.source, required this.study});

  final MaterialRecord material;
  final SourceVersionRecord source;
  final QuizStudyState study;
}

class _QuizFeedback {
  const _QuizFeedback({required this.question, required this.review});

  final QuizQuestionRecord question;
  final QuizQuestionReviewState review;
}

class _QuizLoading extends StatelessWidget {
  const _QuizLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AtelierStyle.canvas,
    appBar: AppBar(
      title: const Text('Quiz'),
      backgroundColor: AtelierStyle.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    body: const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompanionView(state: CompanionVisualState.think, size: 88),
              SizedBox(height: 16),
              Text(
                'Quiz hazırlanıyor…',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.ink, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 7),
              Text(
                'Sorular ve seçenekler yalnız güncel kaynak sürümünden oluşturuluyor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuizError extends StatelessWidget {
  const _QuizError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AtelierStyle.canvas,
    appBar: AppBar(
      title: const Text('Quiz'),
      backgroundColor: AtelierStyle.canvas,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CompanionView(state: CompanionVisualState.think, size: 88),
              const SizedBox(height: 14),
              const Text(
                'Quiz açılamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.ink, fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kaynak değişmiş veya güvenilir seçenekler üretmeye yetecek farklı kavram bulunamamış olabilir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AtelierStyle.muted, height: 1.45),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                key: const ValueKey('quiz-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuizStudyView extends StatelessWidget {
  const _QuizStudyView({
    required this.data,
    required this.selectedOptionIndex,
    required this.feedback,
    required this.busy,
    required this.recoveryNotice,
    required this.scheduledReview,
    required this.onSelect,
    required this.onSubmit,
    required this.onUnknown,
    required this.onContinue,
    required this.onRestart,
  });

  final _QuizViewData data;
  final int? selectedOptionIndex;
  final _QuizFeedback? feedback;
  final bool busy;
  final String? recoveryNotice;
  final bool scheduledReview;
  final ValueChanged<int> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onUnknown;
  final VoidCallback onContinue;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compact = media.size.width < 360 || media.textScaler.scale(1) > 1.2;
    final study = data.study;
    final completed = study.session.isCompleted && feedback == null;
    final question = feedback?.question ?? study.currentQuestion;
    final total = study.set.questions.length;
    final displayOrdinal = feedback?.question.ordinal ?? study.session.cursorIndex;

    return Scaffold(
      key: const ValueKey('quiz-screen'),
      backgroundColor: AtelierStyle.canvas,
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: AtelierStyle.canvas,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: completed
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: const BoxDecoration(
                  color: AtelierStyle.paper,
                  border: Border(top: BorderSide(color: AtelierStyle.line)),
                ),
                child: feedback != null
                    ? FilledButton.icon(
                        key: const ValueKey('quiz-next'),
                        onPressed: busy ? null : onContinue,
                        icon: Icon(
                          scheduledReview
                              ? Icons.check_rounded
                              : study.session.isCompleted
                              ? Icons.fact_check_outlined
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          scheduledReview
                              ? 'Tekrarı tamamla'
                              : study.session.isCompleted
                              ? 'Sonucu gör'
                              : 'Sonraki soru',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AtelierStyle.pulse,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey('quiz-submit'),
                              onPressed: busy || selectedOptionIndex == null ? null : onSubmit,
                              icon: const Icon(Icons.lock_outline_rounded),
                              label: const Text('Yanıtı değerlendir'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AtelierStyle.pulse,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                              ),
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('quiz-unknown'),
                            onPressed: busy ? null : onUnknown,
                            child: const Text('Bilmiyorum'),
                          ),
                        ],
                      ),
              ),
            ),
      body: SafeArea(
        child: completed
            ? _QuizComplete(
                data: data,
                compact: compact,
                busy: busy,
                onReturn: () {
                  Navigator.of(context).maybePop();
                },
                onRestart: onRestart,
              )
            : ListView(
                key: const ValueKey('quiz-scroll'),
                padding: EdgeInsets.fromLTRB(16, 10, 16, compact ? 34 : 46),
                children: [
                  Text(
                    data.material.title,
                    maxLines: compact ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AtelierStyle.ink,
                      fontSize: compact ? 25 : 27,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AtelierSourceTrustStrip(sourceVersion: data.source),
                  if (recoveryNotice != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const ValueKey('quiz-recovery-notice'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AtelierStyle.attentionSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(recoveryNotice!, style: const TextStyle(color: AtelierStyle.ink, height: 1.35)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CompanionView(
                        key: const ValueKey('quiz-companion'),
                        state: feedback == null
                            ? CompanionVisualState.think
                            : feedback!.review.lastIsCorrect == true
                            ? CompanionVisualState.success
                            : CompanionVisualState.think,
                        size: compact ? 64 : 76,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SORU ${displayOrdinal + 1} / $total',
                              style: const TextStyle(
                                color: AtelierStyle.pulse,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feedback == null ? 'Önce kendi yanıtını seç.' : _feedbackHeadline(feedback!.review),
                              style: TextStyle(
                                color: AtelierStyle.ink,
                                fontSize: compact ? 19 : 21,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (question != null)
                    _QuestionCard(
                      question: question,
                      selectedOptionIndex: selectedOptionIndex,
                      feedback: feedback,
                      onSelect: onSelect,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    feedback == null
                        ? 'Yanıtın kalıcı olarak kaydedilmeden önce kaynak kanıtı gösterilmez.'
                        : 'Bu soru sonucu yalnız bu yanıta aittir; genel ustalık veya kalıcılık iddiası değildir.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AtelierStyle.muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
      ),
    );
  }

  static String _feedbackHeadline(QuizQuestionReviewState review) {
    if (review.lastAnswerKind == QuizAnswerKind.unknown) return 'Bilmiyorum olarak kaydedildi.';
    return review.lastIsCorrect == true ? 'Doğru.' : 'Kaynakla eşleşmedi.';
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.selectedOptionIndex,
    required this.feedback,
    required this.onSelect,
  });

  final QuizQuestionRecord question;
  final int? selectedOptionIndex;
  final _QuizFeedback? feedback;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final committed = feedback != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AtelierStyle.paper,
        borderRadius: BorderRadius.circular(20),
        border: const Border(left: BorderSide(color: AtelierStyle.pulse, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x1014224A), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SORU',
            style: TextStyle(color: AtelierStyle.pulse, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 9),
          Semantics(
            label: 'Quiz sorusu: ${question.prompt.replaceAll('_____', 'boşluk')}',
            child: ExcludeSemantics(
              child: Text(
                question.prompt,
                style: const TextStyle(
                  color: AtelierStyle.ink,
                  fontSize: 20,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < question.options.length; index++) ...[
            _OptionTile(
              index: index,
              label: question.options[index],
              selected: !committed && selectedOptionIndex == index,
              committed: committed,
              wasChosen: committed && feedback!.review.lastSelectedOptionIndex == index,
              isCorrect: committed && index == question.correctOptionIndex,
              onTap: committed ? null : () => onSelect(index),
            ),
            if (index != question.options.length - 1) const SizedBox(height: 8),
          ],
          if (committed) ...[
            const SizedBox(height: 18),
            const Divider(color: AtelierStyle.line),
            const SizedBox(height: 14),
            if (feedback!.review.lastAnswerKind == QuizAnswerKind.unknown)
              const Text(
                'Bir seçenek işaretlemedin; bu soru “bilmiyorum” olarak kaydedildi.',
                style: TextStyle(color: AtelierStyle.muted, height: 1.4),
              )
            else
              Text(
                feedback!.review.lastIsCorrect == true
                    ? 'Seçimin kaynakla eşleşiyor.'
                    : 'Doğru yanıt: ${question.options[question.correctOptionIndex]}',
                key: const ValueKey('quiz-answer-feedback'),
                style: const TextStyle(color: AtelierStyle.ink, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('quiz-source-evidence'),
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: AtelierStyle.pulseSoft, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KAYNAKTA',
                    style: TextStyle(
                      color: AtelierStyle.pulse,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(question.sourceExcerpt, style: const TextStyle(color: AtelierStyle.ink, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.label,
    required this.selected,
    required this.committed,
    required this.wasChosen,
    required this.isCorrect,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool committed;
  final bool wasChosen;
  final bool isCorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = committed
        ? isCorrect
              ? Icons.check_circle_rounded
              : wasChosen
              ? Icons.cancel_outlined
              : Icons.radio_button_unchecked_rounded
        : selected
        ? Icons.radio_button_checked_rounded
        : Icons.radio_button_unchecked_rounded;
    final accent = committed && isCorrect ? AtelierStyle.teal : AtelierStyle.pulse;
    return Semantics(
      button: !committed,
      selected: selected,
      label: 'Seçenek ${index + 1}: $label',
      child: Material(
        color: selected || (committed && (isCorrect || wasChosen)) ? AtelierStyle.pulseSoft : AtelierStyle.canvas,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('quiz-option-$index'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AtelierStyle.ink,
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizComplete extends StatelessWidget {
  const _QuizComplete({
    required this.data,
    required this.compact,
    required this.busy,
    required this.onReturn,
    required this.onRestart,
  });

  final _QuizViewData data;
  final bool compact;
  final bool busy;
  final VoidCallback onReturn;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final session = data.study.session;
    final needsRepair = session.incorrectCount > 0 || session.unknownCount > 0;
    return SingleChildScrollView(
      key: const ValueKey('quiz-complete'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.material.title,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AtelierStyle.ink,
              fontSize: compact ? 25 : 27,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          AtelierSourceTrustStrip(sourceVersion: data.source),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AtelierStyle.paper,
              borderRadius: BorderRadius.circular(20),
              border: const Border(left: BorderSide(color: AtelierStyle.teal, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CompanionView(state: CompanionVisualState.success, size: 88),
                const SizedBox(height: 10),
                const Text(
                  'Quiz turu tamamlandı.',
                  style: TextStyle(color: AtelierStyle.ink, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  '${session.correctCount} doğru · ${session.incorrectCount} yanlış · ${session.unknownCount} bilmiyorum',
                  key: const ValueKey('quiz-summary-counts'),
                  style: const TextStyle(color: AtelierStyle.pulse, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bu tur yalnız bu kaynak sürümündeki quiz yanıtlarını özetler; genel ustalık, sınav hazır oluşu veya kalıcı öğrenme iddiası değildir.',
                  style: TextStyle(color: AtelierStyle.muted, height: 1.45),
                ),
                const SizedBox(height: 12),
                Text(
                  needsRepair
                      ? 'Sıradaki yararlı adım: yanlış veya “bilmiyorum” kalan noktaları kaynakta onar, sonra yeniden dene.'
                      : 'Bu turda tüm yanıtların kaynakla eşleşti. Kalıcılık için daha sonra yeniden hatırlama gerekir.',
                  key: const ValueKey('quiz-next-reason'),
                  style: const TextStyle(color: AtelierStyle.ink, height: 1.4, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('quiz-return-workspace'),
                    onPressed: busy ? null : onReturn,
                    icon: Icon(needsRepair ? Icons.menu_book_outlined : Icons.arrow_back_rounded),
                    label: Text(needsRepair ? 'Eksikleri kaynakta onar' : 'Çalışma alanına dön'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AtelierStyle.pulse,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('quiz-restart'),
                    onPressed: busy ? null : onRestart,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Quizi yeniden çöz'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
