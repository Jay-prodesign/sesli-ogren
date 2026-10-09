import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import '../domain/operational_event.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'companion_view.dart';
import 'la0040_visual_treatments.dart';
import 'living_study_desk_home.dart';
import 'atelier_learning_surfaces.dart';

enum _SlicePhase { loading, source, recall, result, continuation, error }

class LearningSliceScreen extends StatefulWidget {
  const LearningSliceScreen({required this.runtime, this.materialId = AppRuntime.primaryMaterialId, super.key});

  final AppRuntime runtime;
  final MaterialId materialId;

  @override
  State<LearningSliceScreen> createState() => _LearningSliceScreenState();
}

class _LearningSliceScreenState extends State<LearningSliceScreen> {
  final _titleController = TextEditingController();
  final _sourceController = TextEditingController();
  final _answerController = TextEditingController();

  _SlicePhase _phase = _SlicePhase.loading;
  RecallPrompt? _prompt;
  RecallAttemptResult? _result;
  LearningContinuation? _continuation;
  RecallAttemptId? _activeAttemptId;
  String? _supportText;
  String? _inlineError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _recordEvent(OperationalEvent event) async {
    try {
      await widget.runtime.telemetry.record(learner: widget.runtime.learner, event: event);
    } catch (_) {
      // Operational telemetry must never become learning-state authority
      // or block the learner's flow.
    }
  }

  Future<void> _restore() async {
    final stopwatch = Stopwatch()..start();
    await _recordEvent(
      OperationalEvent(
        type: OperationalEventType.runtimeRestore,
        phase: OperationalEventPhase.started,
        materialId: widget.materialId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _setBusy(true);
    try {
      final material = await widget.runtime.store.material(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (!mounted) return;

      if (material == null) {
        stopwatch.stop();
        await _recordEvent(
          OperationalEvent(
            type: OperationalEventType.runtimeRestore,
            phase: OperationalEventPhase.completed,
            materialId: widget.materialId,
            durationMs: stopwatch.elapsedMilliseconds,
            createdAt: DateTime.now().toUtc(),
          ),
        );
        if (!mounted) return;
        setState(() {
          _phase = _SlicePhase.source;
          _inlineError = null;
        });
        return;
      }

      final continuation = await widget.runtime.recall.reopen(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
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

      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.runtimeRestore,
          phase: OperationalEventPhase.completed,
          materialId: widget.materialId,
          durationMs: stopwatch.elapsedMilliseconds,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    } catch (error) {
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.runtimeRestore,
          phase: OperationalEventPhase.failed,
          materialId: widget.materialId,
          durationMs: stopwatch.elapsedMilliseconds,
          errorClass: error.runtimeType.toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _phase = _SlicePhase.error;
        _inlineError = 'Devam kaydı kullanılamadı. Kaynaktan güvenli bir hatırlama yeniden başlatabiliriz.';
      });
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _pickPdf() async {
    if (_busy) return;
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      dialogTitle: 'Çalışmak istediğin PDF’i seç',
    );
    if (file == null || !mounted) return;

    final stopwatch = Stopwatch()..start();
    await _recordEvent(
      OperationalEvent(
        type: OperationalEventType.sourceIngest,
        phase: OperationalEventPhase.started,
        materialId: widget.materialId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _setBusy(true);
    try {
      final bytes = await file.readAsBytes();
      final ingestResult = await widget.runtime.ingest.ingestPdf(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
        bytes: bytes,
        originalName: file.name,
      );
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.sourceIngest,
          phase: OperationalEventPhase.completed,
          materialId: widget.materialId,
          sourceVersionId: ingestResult.sourceVersion.identity.sourceVersionId,
          durationMs: stopwatch.elapsedMilliseconds,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.sourceIngest,
          phase: OperationalEventPhase.failed,
          materialId: widget.materialId,
          durationMs: stopwatch.elapsedMilliseconds,
          errorClass: error.runtimeType.toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _inlineError = 'PDF güvenli biçimde işlenemedi. Metin içeren başka bir PDF deneyebilirsin.';
      });
    } finally {
      _setBusy(false);
    }
  }

  String _pastedSourceName(String text) {
    final typed = _titleController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (typed.isNotEmpty) return typed;

    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return 'Çalışma materyalim';
    if (normalized.length <= 72) return normalized;
    return '${normalized.substring(0, 69).trimRight()}…';
  }

  Future<void> _saveSource() async {
    final text = _sourceController.text;
    if (text.trim().isEmpty) {
      setState(() => _inlineError = 'Çalışmak istediğin metni ekle.');
      return;
    }

    final stopwatch = Stopwatch()..start();
    await _recordEvent(
      OperationalEvent(
        type: OperationalEventType.sourceIngest,
        phase: OperationalEventPhase.started,
        materialId: widget.materialId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _setBusy(true);
    try {
      final ingestResult = await widget.runtime.ingest.ingestPastedText(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
        text: text,
        sourceName: _pastedSourceName(text),
      );
      _titleController.clear();
      _sourceController.clear();
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.sourceIngest,
          phase: OperationalEventPhase.completed,
          materialId: widget.materialId,
          sourceVersionId: ingestResult.sourceVersion.identity.sourceVersionId,
          durationMs: stopwatch.elapsedMilliseconds,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.sourceIngest,
          phase: OperationalEventPhase.failed,
          materialId: widget.materialId,
          durationMs: stopwatch.elapsedMilliseconds,
          errorClass: error.runtimeType.toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _inlineError = 'Metin güvenli biçimde işlenemedi. Daha kısa veya farklı bir metin deneyebilirsin.';
      });
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _openRecall() async {
    final stopwatch = Stopwatch()..start();
    await _recordEvent(
      OperationalEvent(
        type: OperationalEventType.recallPrompt,
        phase: OperationalEventPhase.started,
        materialId: widget.materialId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    try {
      final prompt = await widget.runtime.recall.createCurrentPrompt(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      final session = await widget.runtime.recall.openAttempt(learner: widget.runtime.learner, actionId: prompt.id);
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.recallPrompt,
          phase: OperationalEventPhase.completed,
          materialId: prompt.materialId,
          sourceVersionId: prompt.sourceVersionId,
          actionId: prompt.id,
          attemptId: session.attempt.attemptId,
          ruleVersion: prompt.ruleVersion,
          durationMs: stopwatch.elapsedMilliseconds,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      _answerController.clear();
      setState(() {
        _prompt = prompt;
        _result = null;
        _continuation = null;
        _activeAttemptId = session.attempt.attemptId;
        _supportText = _restoredSupportNotice(session.assistance);
        _inlineError = null;
        _phase = _SlicePhase.recall;
      });
    } catch (error) {
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.recallPrompt,
          phase: OperationalEventPhase.failed,
          materialId: widget.materialId,
          durationMs: stopwatch.elapsedMilliseconds,
          errorClass: error.runtimeType.toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      rethrow;
    }
  }

  Future<void> _requestHint() async {
    final prompt = _prompt;
    final attemptId = _activeAttemptId;
    if (prompt == null || attemptId == null || _busy) return;
    _setBusy(true);
    try {
      final support = await widget.runtime.recall.requestHint(
        learner: widget.runtime.learner,
        actionId: prompt.id,
        attemptId: attemptId,
      );
      if (!mounted) return;
      setState(() {
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
    final attemptId = _activeAttemptId;
    if (prompt == null || attemptId == null || _busy) return;
    _setBusy(true);
    try {
      final support = await widget.runtime.recall.revealAnswer(
        learner: widget.runtime.learner,
        actionId: prompt.id,
        attemptId: attemptId,
      );
      if (!mounted) return;
      setState(() {
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
    final attemptId = _activeAttemptId;
    if (prompt == null || attemptId == null || _busy) return;
    if (!unknown && _answerController.text.trim().isEmpty) {
      setState(() => _inlineError = 'Yanıtını yaz veya “Bilmiyorum”u seç.');
      return;
    }

    final stopwatch = Stopwatch()..start();
    await _recordEvent(
      OperationalEvent(
        type: OperationalEventType.recallAttempt,
        phase: OperationalEventPhase.started,
        materialId: prompt.materialId,
        sourceVersionId: prompt.sourceVersionId,
        actionId: prompt.id,
        attemptId: attemptId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _setBusy(true);
    try {
      final result = await widget.runtime.recall.submit(
        learner: widget.runtime.learner,
        actionId: prompt.id,
        attemptId: attemptId,
        disposition: unknown ? RecallResponseDisposition.unknown : RecallResponseDisposition.answer,
        answer: unknown ? '' : _answerController.text,
      );
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.recallAttempt,
          phase: OperationalEventPhase.completed,
          materialId: result.evidence.materialId,
          sourceVersionId: result.evidence.sourceVersionId,
          actionId: result.evidence.actionId,
          attemptId: result.evidence.attemptId,
          evidenceId: result.evidence.id,
          outcome: result.evidence.outcome,
          stateKind: result.state.kind,
          reasonCode: result.nextAction.reasonCode,
          ruleVersion: result.evidence.ruleVersion,
          policyVersion: result.nextAction.policyVersion,
          durationMs: stopwatch.elapsedMilliseconds,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _SlicePhase.result;
        _inlineError = null;
      });
    } catch (error) {
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.recallAttempt,
          phase: OperationalEventPhase.failed,
          materialId: prompt.materialId,
          sourceVersionId: prompt.sourceVersionId,
          actionId: prompt.id,
          attemptId: attemptId,
          durationMs: stopwatch.elapsedMilliseconds,
          errorClass: error.runtimeType.toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      _showRecoverableError();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _repairContinuation() async {
    if (_busy) return;
    final stopwatch = Stopwatch()..start();
    await _recordEvent(
      OperationalEvent(
        type: OperationalEventType.continuationRepair,
        phase: OperationalEventPhase.started,
        materialId: widget.materialId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _setBusy(true);
    try {
      final repaired = await widget.runtime.recall.repairContinuation(
        learner: widget.runtime.learner,
        materialId: widget.materialId,
      );
      if (!mounted) return;

      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.continuationRepair,
          phase: OperationalEventPhase.completed,
          materialId: widget.materialId,
          sourceVersionId: repaired?.state.sourceVersionId,
          evidenceId: repaired?.state.latestEvidenceId,
          ruleVersion: repaired?.state.ruleVersion,
          policyVersion: repaired?.nextAction.policyVersion,
          durationMs: stopwatch.elapsedMilliseconds,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (repaired != null) {
        setState(() {
          _continuation = repaired;
          _phase = _SlicePhase.continuation;
          _inlineError = null;
        });
        return;
      }

      await _openRecall();
    } catch (error) {
      stopwatch.stop();
      await _recordEvent(
        OperationalEvent(
          type: OperationalEventType.continuationRepair,
          phase: OperationalEventPhase.failed,
          materialId: widget.materialId,
          durationMs: stopwatch.elapsedMilliseconds,
          errorClass: error.runtimeType.toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _phase = _SlicePhase.source;
        _inlineError = 'Güvenli devam oluşturulamadı. Kaynağı yeniden ekleyerek başlayabilirsin.';
      });
    } finally {
      _setBusy(false);
    }
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
    _SlicePhase.recall => _busy ? CompanionVisualState.think : CompanionVisualState.listen,
    _SlicePhase.result =>
      _result?.evidence.outcome == RecallOutcome.correct
          ? CompanionVisualState.success
          : CompanionVisualState.correct,
    _SlicePhase.continuation =>
      CompanionVisualState.idle,
    _SlicePhase.error => CompanionVisualState.correct,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.maybeOf(context);
    final reducedMotion = (media?.disableAnimations ?? false) || (media?.accessibleNavigation ?? false);
    final compactResultHeader = _phase == _SlicePhase.result;
    final candidate = LearningVisualTreatmentScope.maybeOf(context);
    final living = LivingDeskReviewScope.active(context);
    final reviewFocus = (candidate != null || living) && (_phase == _SlicePhase.recall || _phase == _SlicePhase.result);
    return Scaffold(
      backgroundColor: living ? AtelierStyle.canvas : null,
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: living
                  ? [AtelierStyle.canvas, AtelierStyle.canvas]
                  : [theme.colorScheme.surface, theme.colorScheme.surfaceContainerLowest],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                children: [
                  if (reviewFocus)
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Çalışmadan çık',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'SESLİ ÖĞREN',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Text(
                          compactResultHeader ? 'SONUÇ' : 'HATIRLA',
                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: compactResultHeader ? AppPalette.successSoft : AppPalette.primarySoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: CompanionView(state: _companionState, size: compactResultHeader ? 58 : 66),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                compactResultHeader ? 'Hatırlama sonucu' : 'Sesli Öğren',
                                style: compactResultHeader
                                    ? theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)
                                    : theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _subtitle(),
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: reviewFocus ? 10 : (compactResultHeader ? 18 : 24)),
                  AnimatedSwitcher(
                    // Never cross-fade whole source/answer stages: old text must not linger or ghost during Recall.
                    duration: reducedMotion || living ? Duration.zero : const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey('${_phase.name}-${_activeAttemptId?.value ?? 'unopened'}'),
                      child: _phaseBody(context),
                    ),
                  ),
                  if (_busy) ...[const SizedBox(height: 20), const LinearProgressIndicator()],
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
          Text('Çalışma materyalini ekle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'PDF seçebilir veya metni doğrudan yapıştırabilirsin. Kaynak sürümü öğrenme kanıtından ayrı tutulur.',
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF seç'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('veya')),
                Expanded(child: Divider()),
              ],
            ),
          ),
          TextField(
            key: const ValueKey('pasted-material-title'),
            controller: _titleController,
            enabled: !_busy,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Başlık (isteğe bağlı)',
              hintText: 'Örn. Biyoloji · Fotosentez',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('pasted-material-text'),
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
          if (_inlineError != null) ...[const SizedBox(height: 12), _InlineNotice(text: _inlineError!)],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _saveSource,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Hatırlama başlat'),
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
    final candidate = LearningVisualTreatmentScope.maybeOf(context);
    if (LivingDeskReviewScope.active(context)) {
      return AtelierRecall(
        prompt: prompt,
        controller: _answerController,
        busy: _busy,
        onSubmit: _submit,
        onHint: _requestHint,
        onReveal: _revealAnswer,
        onUnknown: () => _submit(unknown: true),
        support: _supportText,
        error: _inlineError,
      );
    }
    if (candidate != null) {
      return LearningTreatmentRecallPrompt(
        lane: candidate,
        prompt: prompt,
        controller: _answerController,
        busy: _busy,
        onSubmit: _submit,
        onHint: _requestHint,
        onReveal: _revealAnswer,
        onUnknown: () => _submit(unknown: true),
        supportText: _supportText,
        errorText: _inlineError,
      );
    }
    return _SurfaceCard(
      key: const ValueKey('recall'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(999)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'KAYNAĞA BAKMADAN',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: AppPalette.primary, fontWeight: FontWeight.w900, letterSpacing: 0.45),
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.psychology_alt_outlined, color: AppPalette.primary, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text('Hatırla', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(prompt.promptText, style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.35)),
          const SizedBox(height: 20),
          TextField(
            controller: _answerController,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Yanıtın', border: OutlineInputBorder()),
          ),
          if (_supportText != null) ...[const SizedBox(height: 12), _InlineNotice(text: _supportText!)],
          if (_inlineError != null) ...[const SizedBox(height: 12), _InlineNotice(text: _inlineError!)],
          const SizedBox(height: 18),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Yanıtla')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(onPressed: _busy ? null : _requestHint, child: const Text('İpucu')),
              OutlinedButton(onPressed: _busy ? null : _revealAnswer, child: const Text('Yanıtı göster')),
              TextButton(onPressed: _busy ? null : () => _submit(unknown: true), child: const Text('Bilmiyorum')),
            ],
          ),
        ],
      ),
    );
  }

  /// Highlight only an exact literal answer span; never fabricate a source match.
  Widget _sourceProofText(BuildContext context, RecallAttemptResult result) {
    final excerpt = result.sourceExcerpt;
    final answer = result.correctAnswer.trim();
    final at = answer.isEmpty ? -1 : excerpt.indexOf(answer);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    if (at < 0) {
      return SelectableText(excerpt, style: style);
    }
    return SelectableText.rich(
      TextSpan(
        style: style,
        children: [
          if (at > 0) TextSpan(text: excerpt.substring(0, at)),
          TextSpan(
            text: excerpt.substring(at, at + answer.length),
            style: const TextStyle(
              backgroundColor: AppPalette.signalSoft,
              fontWeight: FontWeight.w800,
              color: AppPalette.primaryDark,
            ),
          ),
          if (at + answer.length < excerpt.length)
            TextSpan(text: excerpt.substring(at + answer.length)),
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context) {
    final result = _result;
    if (result == null) return _errorCard(context);
    final candidate = LearningVisualTreatmentScope.maybeOf(context);
    if (LivingDeskReviewScope.active(context)) {
      return AtelierResult(
        result: result,
        answerInMemory: _answerController.text,
        onContinue: () {
          setState(() {
            _continuation = LearningContinuation(state: result.state, nextAction: result.nextAction);
            _phase = _SlicePhase.continuation;
          });
        },
      );
    }
    if (candidate != null) {
      return LearningTreatmentResult(
        lane: candidate,
        result: result,
        onContinue: () {
          setState(() {
            _continuation = LearningContinuation(state: result.state, nextAction: result.nextAction);
            _phase = _SlicePhase.continuation;
          });
        },
      );
    }
    final theme = Theme.of(context);
    final isIndependent = result.evidence.outcome == RecallOutcome.correct;

    return _SurfaceCard(
      key: const ValueKey('result'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: isIndependent ? AppPalette.successSoft : AppPalette.attentionSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isIndependent ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded,
                    color: isIndependent ? AppPalette.success : AppPalette.attention,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIndependent ? 'İpucusuz hatırladın' : 'Geri bildirim',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(_outcomeText(result.evidence.outcome)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'SENİN DENEMEN',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppPalette.inkMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _answerController.text.trim().isEmpty
                ? 'Bu denemede yazılı yanıt verilmedi.'
                : _answerController.text.trim(),
            style: theme.textTheme.titleMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text('Kaynakla karşılaştır', style: theme.textTheme.titleMedium)),
              DecoratedBox(
                decoration: BoxDecoration(color: AppPalette.signalSoft, borderRadius: BorderRadius.circular(999)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  child: Text(
                    'KAYNAK',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppPalette.signal,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Doğru ifade', style: theme.textTheme.labelMedium?.copyWith(color: AppPalette.inkMuted)),
                  const SizedBox(height: 6),
                  Text(result.correctAnswer, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppPalette.outline),
                  const SizedBox(height: 13),
                  Text('Kaynak bağlamı', style: theme.textTheme.labelMedium?.copyWith(color: AppPalette.inkMuted)),
                  const SizedBox(height: 5),
                  _sourceProofText(context, result),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(color: AppPalette.primaryDark, borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: AppPalette.momentum, borderRadius: BorderRadius.circular(999)),
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(Icons.arrow_forward_rounded, color: AppPalette.momentumInk, size: 17),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sıradaki adım', style: theme.textTheme.labelLarge?.copyWith(color: Colors.white)),
                        const SizedBox(height: 5),
                        Text(
                          result.nextAction.reasonText,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.82)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              setState(() {
                _continuation = LearningContinuation(state: result.state, nextAction: result.nextAction);
                _phase = _SlicePhase.continuation;
              });
            },
            child: const Text('Sıradaki adıma geç'),
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
          Text('Devam noktası', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(continuation.nextAction.reasonText),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _openRecall,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Hatırlamaya dön'),
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
          Text('Güvenli devam', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(_inlineError ?? 'Devam bilgisi eksik. Kaynaktan yeni bir Recall başlatabiliriz.'),
          const SizedBox(height: 18),
          FilledButton(onPressed: _busy ? null : _repairContinuation, child: const Text('Devamı onar')),
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

  static String? _restoredSupportNotice(RecallAssistance assistance) => switch (assistance) {
    RecallAssistance.none => null,
    RecallAssistance.hint => 'Bu denemede daha önce ipucu kullandın. Sonuç bağımsız hatırlama sayılmayacak.',
    RecallAssistance.answerExposed => 'Bu denemede yanıt daha önce gösterildi. Sonuç bağımsız hatırlama sayılmayacak.',
  };

  static String _outcomeText(RecallOutcome outcome) => switch (outcome) {
    RecallOutcome.correct => 'Bu yanıtı yardım almadan geri çağırdın. Bunu tek başına ustalık olarak yorumlamıyoruz.',
    RecallOutcome.helpedCorrect => 'Doğru yanıta ipucuyla ulaştın. Bu yüzden bağımsız hatırlama sayılmadı.',
    RecallOutcome.answerExposed => 'Yanıtı gördün. Bu deneme geri çağırma başarısı olarak sayılmadı.',
    RecallOutcome.partial => 'Yanıtın çok yaklaştı; kaynakla karşılaştırıp tekrar denemek daha doğru.',
    RecallOutcome.incorrect => 'Bu kez eşleşmedi. Bu bir etiket değil; yalnızca bu denemenin sonucu.',
    RecallOutcome.unknown => 'Bu denemede değerlendirilebilir bir yanıt yok. Durumun bilinmiyor olarak kaldı.',
  };
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.title, required this.body, super.key});

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
        child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
      ),
    );
  }
}
