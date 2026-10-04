import 'package:flutter/material.dart';

import '../domain/learning_truth.dart';
import 'app_runtime.dart';
import 'companion_view.dart';

enum _SlicePhase { loading, source, recall, result, continuation, error }

class LearningSliceScreen extends StatefulWidget {
  const LearningSliceScreen({
    required this.runtime,
    super.key,
  });

  final AppRuntime runtime;

  @override
  State<LearningSliceScreen> createState() => _LearningSliceScreenState();
}

class _LearningSliceScreenState extends State<LearningSliceScreen> {
  final _sourceController = TextEditingController();
  final _answerController = TextEditingController();

  _SlicePhase _phase = _SlicePhase.loading;
  RecallPrompt? _prompt;
  RecallAttemptResult? _result;
  LearningContinuation? _continuation;
  RecallAssistance _assistance = RecallAssistance.none;
  String? _supportText;
  String? _inlineError;
  bool _busy = false;
  int _attemptSequence = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    _setBusy(true);
    try {
      final material = await widget.runtime.store.material(
        learner: AppRuntime.learner,
        materialId: AppRuntime.primaryMaterialId,
      );
      if (!mounted) return;

      if (material == null) {
        setState(() {
          _phase = _SlicePhase.source;
          _inlineError = null;
        });
        return;
      }

      final continuation = await widget.runtime.recall.reopen(
        learner: AppRuntime.learner,
        materialId: AppRuntime.primaryMaterialId,
      );
      if (!mounted) return;

      if (continuation != null) {
        setState(() {
          _continuation = continuation;
          _phase = _SlicePhase.continuation;
          _inlineError = null;
        });
      } else {
        await _openRecall();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _SlicePhase.error;
        _inlineError =
            'Devam kaydı kullanılamadı. Kaynaktan güvenli bir Recall yeniden başlatabiliriz.';
      });
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _saveSource() async {
    final text = _sourceController.text;
    if (text.trim().isEmpty) {
      setState(() => _inlineError = 'Çalışmak istediğin metni ekle.');
      return;
    }

    _setBusy(true);
    try {
      await widget.runtime.ingest.ingestPastedText(
        learner: AppRuntime.learner,
        materialId: AppRuntime.primaryMaterialId,
        text: text,
        sourceName: 'Çalışma materyalim',
      );
      _sourceController.clear();
      await _openRecall();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError =
            'Metin güvenli biçimde işlenemedi. Daha kısa veya farklı bir metin deneyebilirsin.';
      });
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _openRecall() async {
    final prompt = await widget.runtime.recall.createCurrentPrompt(
      learner: AppRuntime.learner,
      materialId: AppRuntime.primaryMaterialId,
    );
    if (!mounted) return;
    _answerController.clear();
    setState(() {
      _prompt = prompt;
      _result = null;
      _continuation = null;
      _assistance = RecallAssistance.none;
      _supportText = null;
      _inlineError = null;
      _phase = _SlicePhase.recall;
    });
  }

  Future<void> _requestHint() async {
    final prompt = _prompt;
    if (prompt == null || _busy) return;
    _setBusy(true);
    try {
      final support = await widget.runtime.recall.requestHint(
        learner: AppRuntime.learner,
        actionId: prompt.id,
      );
      if (!mounted) return;
      setState(() {
        if (_assistance != RecallAssistance.answerExposed) {
          _assistance = support.assistance;
        }
        _supportText = support.text;
        _inlineError = null;
      });
    } catch (_) {
      _showRecoverableError();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _revealAnswer() async {
    final prompt = _prompt;
    if (prompt == null || _busy) return;
    _setBusy(true);
    try {
      final support = await widget.runtime.recall.revealAnswer(
        learner: AppRuntime.learner,
        actionId: prompt.id,
      );
      if (!mounted) return;
      setState(() {
        _assistance = support.assistance;
        _supportText = 'Yanıt: ${support.text}';
        _answerController.text = support.text;
        _inlineError = null;
      });
    } catch (_) {
      _showRecoverableError();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _submit({bool unknown = false}) async {
    final prompt = _prompt;
    if (prompt == null || _busy) return;
    if (!unknown && _answerController.text.trim().isEmpty) {
      setState(() => _inlineError = 'Yanıtını yaz veya “Bilmiyorum”u seç.');
      return;
    }

    _setBusy(true);
    try {
      final result = await widget.runtime.recall.submit(
        learner: AppRuntime.learner,
        actionId: prompt.id,
        attemptId: RecallAttemptId(_nextAttemptId()),
        disposition: unknown
            ? RecallResponseDisposition.unknown
            : RecallResponseDisposition.answer,
        answer: unknown ? '' : _answerController.text,
        assistance: unknown ? RecallAssistance.none : _assistance,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _SlicePhase.result;
        _inlineError = null;
      });
    } catch (_) {
      _showRecoverableError();
    } finally {
      _setBusy(false);
    }
  }

  String _nextAttemptId() {
    _attemptSequence++;
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'attempt-$micros-$_attemptSequence';
  }

  void _showRecoverableError() {
    if (!mounted) return;
    setState(() {
      _phase = _SlicePhase.error;
      _inlineError =
          'Bu öğrenme adımı artık güncel kaynakla eşleşmiyor. Kaynaktan güvenli biçimde yeniden başlayabiliriz.';
    });
  }

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() => _busy = value);
  }

  CompanionVisualState get _companionState => switch (_phase) {
    _SlicePhase.loading => CompanionVisualState.think,
    _SlicePhase.source => CompanionVisualState.idle,
    _SlicePhase.recall => _busy
        ? CompanionVisualState.think
        : CompanionVisualState.listen,
    _SlicePhase.result => _result?.state.kind == RecallStateKind.retrievedOnce
        ? CompanionVisualState.success
        : CompanionVisualState.correct,
    _SlicePhase.continuation =>
      _continuation?.state.kind == RecallStateKind.retrievedOnce
          ? CompanionVisualState.success
          : CompanionVisualState.idle,
    _SlicePhase.error => CompanionVisualState.correct,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerLowest,
              ],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: CompanionView(state: _companionState, size: 124),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Sesli Öğren',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _phaseBody(context),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 20),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() => switch (_phase) {
    _SlicePhase.loading => 'Öğrenme durumunu hazırlıyorum.',
    _SlicePhase.source => 'Kendi materyalinle başlayalım.',
    _SlicePhase.recall => 'Kaynaktan hatırlamayı dene.',
    _SlicePhase.result => 'Yanıtını kaynakla karşılaştırdım.',
    _SlicePhase.continuation => 'Bir sonraki adımın hazır.',
    _SlicePhase.error => 'Kaynağın güvende; devam durumunu onarabiliriz.',
  };

  Widget _phaseBody(BuildContext context) => switch (_phase) {
    _SlicePhase.loading => const _MessageCard(
        key: ValueKey('loading'),
        title: 'Hazırlanıyor',
        body: 'Kaynak ve son öğrenme durumun kontrol ediliyor.',
      ),
    _SlicePhase.source => _sourceCard(context),
    _SlicePhase.recall => _recallCard(context),
    _SlicePhase.result => _resultCard(context),
    _SlicePhase.continuation => _continuationCard(context),
    _SlicePhase.error => _errorCard(context),
  };

  Widget _sourceCard(BuildContext context) {
    return _SurfaceCard(
      key: const ValueKey('source'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Çalışma materyalini ekle',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu ilk dilimde metni doğrudan yapıştırıyoruz. Kaynak sürümü ve öğrenme kanıtı cihazda ayrı ve kalıcı tutulur.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _sourceController,
            minLines: 7,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Metin',
              hintText: 'Notunu veya çalışmak istediğin bölümü buraya yapıştır.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 12),
            _InlineNotice(text: _inlineError!),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _saveSource,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Recall oluştur'),
          ),
        ],
      ),
    );
  }

  Widget _recallCard(BuildContext context) {
    final prompt = _prompt;
    if (prompt == null) {
      return _errorCard(context);
    }
    return _SurfaceCard(
      key: const ValueKey('recall'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hatırla', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Text(
            prompt.promptText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _answerController,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Yanıtın',
              border: OutlineInputBorder(),
            ),
          ),
          if (_supportText != null) ...[
            const SizedBox(height: 12),
            _InlineNotice(text: _supportText!),
          ],
          if (_inlineError != null) ...[
            const SizedBox(height: 12),
            _InlineNotice(text: _inlineError!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('Yanıtla'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _requestHint,
                child: const Text('İpucu'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _revealAnswer,
                child: const Text('Yanıtı göster'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _submit(unknown: true),
                child: const Text('Bilmiyorum'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context) {
    final result = _result;
    if (result == null) return _errorCard(context);
    final theme = Theme.of(context);
    final isIndependent = result.evidence.outcome == RecallOutcome.correct;

    return _SurfaceCard(
      key: const ValueKey('result'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isIndependent ? 'İpucusuz hatırladın' : 'Geri bildirim',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(_outcomeText(result.evidence.outcome)),
          const SizedBox(height: 18),
          Text('Doğru ifade', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            result.correctAnswer,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text('Kaynak bağlamı', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            result.sourceExcerpt,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 32),
          Text('Sıradaki adım', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(result.nextAction.reasonText),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              setState(() {
                _continuation = LearningContinuation(
                  state: result.state,
                  nextAction: result.nextAction,
                );
                _phase = _SlicePhase.continuation;
              });
            },
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
  }

  Widget _continuationCard(BuildContext context) {
    final continuation = _continuation;
    if (continuation == null) return _errorCard(context);
    return _SurfaceCard(
      key: const ValueKey('continuation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Devam noktası',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(continuation.nextAction.reasonText),
          const SizedBox(height: 10),
          Text(
            'Neden: ${continuation.nextAction.reasonCode}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _openRecall,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Recall’u aç'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _sourceController.clear();
                      _inlineError = null;
                      _phase = _SlicePhase.source;
                    });
                  },
            child: const Text('Materyali güncelle'),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    return _SurfaceCard(
      key: const ValueKey('error'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Güvenli devam',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            _inlineError ??
                'Devam bilgisi eksik. Kaynaktan yeni bir Recall başlatabiliriz.',
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    _setBusy(true);
                    try {
                      await _openRecall();
                    } catch (_) {
                      if (!mounted) return;
                      setState(() {
                        _phase = _SlicePhase.source;
                        _inlineError =
                            'Mevcut kaynakla devam edemedik. Metni yeniden ekleyebilirsin.';
                      });
                    } finally {
                      _setBusy(false);
                    }
                  },
            child: const Text('Kaynaktan yeniden başla'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _phase = _SlicePhase.source;
                      _inlineError = null;
                    });
                  },
            child: const Text('Metin ekle'),
          ),
        ],
      ),
    );
  }

  static String _outcomeText(RecallOutcome outcome) => switch (outcome) {
    RecallOutcome.correct =>
      'Bu yanıtı yardım almadan geri çağırdın. Bunu tek başına ustalık olarak yorumlamıyoruz.',
    RecallOutcome.helpedCorrect =>
      'Doğru yanıta ipucuyla ulaştın. Bu yüzden bağımsız hatırlama sayılmadı.',
    RecallOutcome.answerExposed =>
      'Yanıtı gördün. Bu deneme geri çağırma başarısı olarak sayılmadı.',
    RecallOutcome.partial =>
      'Yanıtın çok yaklaştı; kaynakla karşılaştırıp tekrar denemek daha doğru.',
    RecallOutcome.incorrect =>
      'Bu kez eşleşmedi. Bu bir etiket değil; yalnızca bu denemenin sonucu.',
    RecallOutcome.unknown =>
      'Bu denemede değerlendirilebilir bir yanıt yok. Durumun bilinmiyor olarak kaldı.',
  };
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: child,
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(text),
        ),
      ),
    );
  }
}
