import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/learning_contracts.dart';
import '../domain/reader_annotation.dart';

import 'atelier_learning_surfaces.dart';
import 'living_study_desk_home.dart';
import 'source_text_matching.dart';

/// Read the complete locally extracted source without sending it to a model.
class SourceReaderScreen extends StatefulWidget {
  const SourceReaderScreen({
    required this.title,
    required this.sourceText,
    this.sourceVersion,
    this.sourceWarnings = const [],
    this.initialProgress = 0,
    this.onProgressChanged,
    this.sourceAnchors = const [],
    this.initialAnnotations = const [],
    this.staleAnnotationCount = 0,
    this.onSaveAnnotation,
    this.onDeleteAnnotation,
    this.onTutorSelection,
    this.onRecallSelection,
    this.onListen,
    this.onRecap,
    this.onRecall,
    super.key,
  });

  final String title;
  final String sourceText;
  final SourceVersionRecord? sourceVersion;
  final List<String> sourceWarnings;
  final double initialProgress;
  final Future<void> Function(double progress)? onProgressChanged;
  final List<SourceAnchor> sourceAnchors;
  final List<ReaderAnnotationRecord> initialAnnotations;
  final int staleAnnotationCount;
  final Future<ReaderAnnotationRecord> Function(
    SourceAnchor anchor,
    String selectedText,
    ReaderAnnotationKind kind,
    String? noteText,
  )?
  onSaveAnnotation;
  final Future<void> Function(ReaderAnnotationId annotationId)? onDeleteAnnotation;
  final void Function(SourceAnchor anchor)? onTutorSelection;
  final void Function(SourceAnchor anchor)? onRecallSelection;
  final VoidCallback? onListen;
  final VoidCallback? onRecap;
  final VoidCallback? onRecall;

  @override
  State<SourceReaderScreen> createState() => _SourceReaderScreenState();
}

class _SourceReaderScreenState extends State<SourceReaderScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _readingScroll = ScrollController();
  double _readingProgress = 0;
  double _lastReportedProgress = 0;
  double _fontSize = 17;
  bool _showSearch = false;
  bool _sourceFitsViewport = false;
  bool _initialProgressRestored = false;
  bool _progressSaveWarningShown = false;
  late List<ReaderAnnotationRecord> _annotations;
  SourceAnchor? _selectedAnchor;
  String? _selectedText;
  bool _annotationBusy = false;
  String? _annotationError;

  @override
  void initState() {
    super.initState();
    _readingProgress = widget.initialProgress.clamp(0.0, 1.0);
    _lastReportedProgress = _readingProgress;
    _annotations = [...widget.initialAnnotations];
    _readingScroll.addListener(_updateReadingProgress);
    _scheduleReadingProgressUpdate();
  }

  @override
  void didUpdateWidget(covariant SourceReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAnnotations != widget.initialAnnotations) {
      _annotations = [...widget.initialAnnotations];
    }
    if (oldWidget.sourceText != widget.sourceText || oldWidget.initialProgress != widget.initialProgress) {
      _readingProgress = widget.initialProgress.clamp(0.0, 1.0);
      _lastReportedProgress = _readingProgress;
      _sourceFitsViewport = false;
      _initialProgressRestored = false;
      _scheduleReadingProgressUpdate();
    }
  }

  @override
  void dispose() {
    if (!_sourceFitsViewport) {
      _reportProgress(_readingProgress, force: true);
    }
    _readingScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _scheduleReadingProgressUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreInitialProgress();
      _updateReadingProgress();
    });
  }

  void _restoreInitialProgress() {
    if (_initialProgressRestored || !_readingScroll.hasClients) return;
    final max = _readingScroll.position.maxScrollExtent;
    _initialProgressRestored = true;
    if (max <= 0 || widget.initialProgress <= 0) return;
    _readingScroll.jumpTo((max * widget.initialProgress.clamp(0.0, 1.0)).clamp(0.0, max));
  }

  void _reportProgress(double progress, {bool force = false}) {
    final callback = widget.onProgressChanged;
    if (callback == null || _sourceFitsViewport) return;
    if (!force && (progress - _lastReportedProgress).abs() < 0.05 && progress != 0 && progress != 1) return;
    _lastReportedProgress = progress;
    unawaited(
      callback(progress).catchError((Object _) {
        if (!mounted || _progressSaveWarningShown) return;
        _progressSaveWarningShown = true;
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(const SnackBar(content: Text('Okuma konumu kaydedilemedi. Kaynağın kendisi korunuyor.')));
      }),
    );
  }

  void _updateReadingProgress() {
    if (!_readingScroll.hasClients) return;
    final position = _readingScroll.position;
    final max = position.maxScrollExtent;
    final fitsViewport = max <= 0;
    final progress = fitsViewport ? 1.0 : (position.pixels / max).clamp(0.0, 1.0);
    if ((progress - _readingProgress).abs() >= 0.01 ||
        fitsViewport != _sourceFitsViewport ||
        progress == 0 ||
        progress == 1.0) {
      setState(() {
        _readingProgress = progress;
        _sourceFitsViewport = fitsViewport;
      });
    }
    if (!fitsViewport) _reportProgress(progress);
  }

  void _setReadingFontSize(double value) {
    final next = value.clamp(14.0, 26.0).toDouble();
    if (next == _fontSize) return;
    setState(() => _fontSize = next);
    _scheduleReadingProgressUpdate();
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    _scheduleReadingProgressUpdate();
  }

  void _searchChanged() {
    setState(() {});
    _scheduleReadingProgressUpdate();
  }

  int? _pageForSelection(int start, int end) {
    for (final anchor in widget.sourceAnchors) {
      if (start >= anchor.startOffset && end <= anchor.endOffset) {
        return anchor.pageNumber;
      }
    }
    return null;
  }

  void _selectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    if (selection.isCollapsed) return;
    final source = widget.sourceText.trim();
    final start = selection.start < selection.end ? selection.start : selection.end;
    final end = selection.start < selection.end ? selection.end : selection.start;
    if (start < 0 || end <= start || end > source.length || end - start > 2000) {
      setState(() {
        _selectedAnchor = null;
        _selectedText = null;
        _annotationError = 'Bu seçim kaynakta güvenli bir işaret oluşturmak için kullanılamıyor.';
      });
      return;
    }
    final selected = source.substring(start, end);
    setState(() {
      _selectedAnchor = SourceAnchor(startOffset: start, endOffset: end, pageNumber: _pageForSelection(start, end));
      _selectedText = selected;
      _annotationError = null;
    });
  }

  void _clearSelectionContext() {
    setState(() {
      _selectedAnchor = null;
      _selectedText = null;
      _annotationError = null;
    });
  }

  Future<void> _saveAnnotation(ReaderAnnotationKind kind, {String? noteText}) async {
    final callback = widget.onSaveAnnotation;
    final anchor = _selectedAnchor;
    final selected = _selectedText;
    if (callback == null || anchor == null || selected == null || _annotationBusy) return;
    setState(() {
      _annotationBusy = true;
      _annotationError = null;
    });
    try {
      final saved = await callback(anchor, selected, kind, noteText);
      if (!mounted) return;
      setState(() {
        _annotations = [..._annotations.where((item) => item.id != saved.id), saved]
          ..sort((left, right) => left.sourceAnchor.startOffset.compareTo(right.sourceAnchor.startOffset));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _annotationError = 'İşaret kaydedilemedi. Kaynak değişmiş olabilir; Reader’ı yeniden açıp tekrar dene.';
      });
    } finally {
      if (mounted) setState(() => _annotationBusy = false);
    }
  }

  Future<void> _addNoteForSelection() async {
    final anchor = _selectedAnchor;
    final selected = _selectedText;
    if (anchor == null || selected == null || _annotationBusy) return;
    var draft = '';
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bu bölüme not ekle'),
        content: TextFormField(
          key: const ValueKey('reader-note-input'),
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          maxLength: 4000,
          onChanged: (value) => draft = value,
          decoration: const InputDecoration(
            hintText: 'Bu bölümde neyi hatırlamak istiyorsun?',
            helperText: 'Not, öğrenme kanıtı sayılmaz.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Vazgeç')),
          FilledButton(
            key: const ValueKey('reader-note-save'),
            onPressed: () {
              final value = draft.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Notu kaydet'),
          ),
        ],
      ),
    );
    if (note == null || !mounted) return;
    await _saveAnnotation(ReaderAnnotationKind.note, noteText: note);
  }

  Future<void> _editNote(ReaderAnnotationRecord annotation) async {
    if (_annotationBusy || widget.onSaveAnnotation == null) return;
    var draft = annotation.noteText ?? '';
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notu düzenle'),
        content: TextFormField(
          key: const ValueKey('reader-note-edit-input'),
          initialValue: draft,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          maxLength: 4000,
          onChanged: (value) => draft = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final value = draft.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (note == null || !mounted) return;
    setState(() {
      _selectedAnchor = annotation.sourceAnchor;
      _selectedText = annotation.selectedText;
    });
    await _saveAnnotation(ReaderAnnotationKind.note, noteText: note);
  }

  Future<void> _deleteAnnotation(ReaderAnnotationRecord annotation) async {
    final callback = widget.onDeleteAnnotation;
    if (callback == null || _annotationBusy) return;
    setState(() {
      _annotationBusy = true;
      _annotationError = null;
    });
    try {
      await callback(annotation.id);
      if (!mounted) return;
      setState(() {
        _annotations = _annotations.where((item) => item.id != annotation.id).toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _annotationError = 'İşaret silinemedi. Tekrar deneyebilirsin.');
    } finally {
      if (mounted) setState(() => _annotationBusy = false);
    }
  }

  List<TextSpan> _sourceSpans({
    required String source,
    required List<SourceTextRange> matches,
    required Color ink,
    required Color searchHighlight,
    required Color annotationHighlight,
  }) {
    final boundaries = <int>{0, source.length};
    for (final match in matches) {
      boundaries
        ..add(match.start)
        ..add(match.end);
    }
    for (final annotation in _annotations) {
      final start = annotation.sourceAnchor.startOffset.clamp(0, source.length);
      final end = annotation.sourceAnchor.endOffset.clamp(start, source.length);
      boundaries
        ..add(start)
        ..add(end);
    }
    final sorted = boundaries.toList()..sort();
    final spans = <TextSpan>[];
    for (var index = 0; index < sorted.length - 1; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (end <= start) continue;
      final inSearch = matches.any((match) => start >= match.start && end <= match.end);
      final annotation = _annotations.cast<ReaderAnnotationRecord?>().firstWhere(
        (item) => item != null && start >= item.sourceAnchor.startOffset && end <= item.sourceAnchor.endOffset,
        orElse: () => null,
      );
      spans.add(
        TextSpan(
          text: source.substring(start, end),
          style: TextStyle(
            color: ink,
            backgroundColor: inSearch
                ? searchHighlight
                : annotation != null
                ? annotationHighlight
                : null,
            fontWeight: inSearch ? FontWeight.w700 : null,
            decoration: annotation?.kind == ReaderAnnotationKind.note ? TextDecoration.underline : null,
            decorationThickness: annotation?.kind == ReaderAnnotationKind.note ? 1.5 : null,
          ),
        ),
      );
    }
    return spans;
  }

  Future<void> _runLearningAction(VoidCallback? action) async {
    final callback = widget.onProgressChanged;
    if (callback != null) {
      try {
        await callback(_readingProgress);
        _lastReportedProgress = _readingProgress;
      } catch (_) {
        if (mounted && !_progressSaveWarningShown) {
          _progressSaveWarningShown = true;
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(const SnackBar(content: Text('Okuma konumu kaydedilemedi. Kaynağın kendisi korunuyor.')));
        }
      }
    }
    if (!mounted) return;
    final media = MediaQuery.maybeOf(context);
    final quietFeedback = (media?.disableAnimations ?? false) || (media?.accessibleNavigation ?? false);
    if (!quietFeedback) {
      try {
        unawaited(HapticFeedback.selectionClick().catchError((_) {}));
      } catch (_) {
        // Haptics are acknowledgement only; they must never block navigation.
      }
    }
    if (!mounted) return;
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final living = LivingDeskReviewScope.active(context);
    final query = _search.text.trim();
    final source = widget.sourceText.trim();
    final matches = findTurkishSourceTextMatches(source, query);
    final ink = living ? AtelierStyle.ink : theme.colorScheme.onSurface;
    final accent = living ? AtelierStyle.teal : theme.colorScheme.primary;
    final line = living ? AtelierStyle.line : theme.colorScheme.outlineVariant;
    final paper = living ? AtelierStyle.paper : theme.colorScheme.surface;
    final canvas = living ? AtelierStyle.canvas : theme.colorScheme.surface;
    final sourceWarning = widget.sourceWarnings.contains('OCR_TEXT_REQUIRES_SOURCE_CHECK')
        ? 'Bu metin fotoğraftan OCR ile okundu. Çalışmadan önce ifadeleri görsel kaynakla karşılaştır.'
        : widget.sourceWarnings.contains('PPTX_SLIDE_TEXT_ONLY')
        ? 'Bu sunuda yalnız okunabilir slayt metni çıkarıldı; görsel yerleşim ve grafikler kaynak metne dönüşmedi.'
        : widget.sourceWarnings.contains('DOCX_LAYOUT_NOT_PRESERVED')
        ? 'Bu Word belgesinde okunabilir metin çıkarıldı; sayfa yerleşimi kaynak metne dönüşmedi.'
        : widget.sourceWarnings.contains('LEGACY_DOC_TEXT_ONLY')
        ? 'Bu eski Word dosyasında yalnız doğrulanabilen metin çıkarıldı; sayfa düzeni ve gömülü nesneler kaynak metne dönüşmedi.'
        : widget.sourceWarnings.contains('LEGACY_PPT_TEXT_ONLY')
        ? 'Bu eski PowerPoint dosyasında yalnız doğrulanabilen slayt metni çıkarıldı; görsel yerleşim ve nesneler kaynak metne dönüşmedi.'
        : null;
    final restoredFromSavedPosition = widget.initialProgress > 0.02 && widget.initialProgress < 0.95;
    final compactReadingSurface =
        MediaQuery.sizeOf(context).width < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.2;

    final spans = _sourceSpans(
      source: source,
      matches: matches,
      ink: ink,
      searchHighlight: living ? AtelierStyle.mark : theme.colorScheme.tertiaryContainer,
      annotationHighlight: living ? AtelierStyle.mint : theme.colorScheme.secondaryContainer,
    );

    final article = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (living) ...[
          Text(
            'KAYNAK · OKUMA',
            style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w900, letterSpacing: 0.9),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(color: ink, fontWeight: living ? FontWeight.w900 : null),
        ),
        if (living && widget.sourceVersion != null) ...[
          const SizedBox(height: 12),
          AtelierSourceTrustStrip(sourceVersion: widget.sourceVersion!),
        ],
        if (sourceWarning != null) ...[
          const SizedBox(height: 10),
          Semantics(
            container: true,
            liveRegion: true,
            label: sourceWarning,
            child: ExcludeSemantics(
              child: Container(
                key: const ValueKey('reader-source-warning'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: living ? AtelierStyle.pulseSoft : theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.fact_check_outlined, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(sourceWarning, style: theme.textTheme.bodySmall?.copyWith(color: ink, height: 1.35)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (widget.staleAnnotationCount > 0) ...[
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('reader-stale-annotations'),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: living ? AtelierStyle.attentionSoft : theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.staleAnnotationCount} eski işaret önceki kaynak sürümüne bağlı. '
              'Bu sürümde uygulanmıyor; yeniden bağlanmış sayılmıyor.',
              style: theme.textTheme.bodySmall?.copyWith(color: ink, height: 1.35),
            ),
          ),
        ],
        if (living && !compactReadingSurface) ...[
          const SizedBox(height: 14),
          const AtelierLearningRail(phase: AtelierLearningPhase.source),
        ],
        const SizedBox(height: 16),
        SelectableText.rich(
          TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(color: ink, fontSize: _fontSize, height: 1.65),
            children: spans,
          ),
          key: const ValueKey('reader-selectable-source'),
          onSelectionChanged: _selectionChanged,
        ),
        if (_annotations.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'İşaretlerin',
            style: theme.textTheme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ..._annotations.map(
            (annotation) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                key: ValueKey('reader-annotation-${annotation.id.value}'),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: living ? AtelierStyle.mint : theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      annotation.kind == ReaderAnnotationKind.note
                          ? Icons.note_alt_outlined
                          : Icons.border_color_outlined,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            annotation.selectedText,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: ink, fontWeight: FontWeight.w800),
                          ),
                          if ((annotation.noteText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(annotation.noteText!, style: theme.textTheme.bodySmall?.copyWith(color: ink)),
                          ],
                        ],
                      ),
                    ),
                    if (annotation.kind == ReaderAnnotationKind.note)
                      IconButton(
                        tooltip: 'Notu düzenle',
                        onPressed: _annotationBusy ? null : () => _editNote(annotation),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    IconButton(
                      tooltip: 'İşareti sil',
                      onPressed: _annotationBusy ? null : () => _deleteAnnotation(annotation),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Metinde ara',
            onPressed: _toggleSearch,
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
          ),
          PopupMenuButton<String>(
            tooltip: 'Okuma ve öğrenme seçenekleri',
            onSelected: (action) {
              switch (action) {
                case 'listen':
                  unawaited(_runLearningAction(widget.onListen));
                  break;
                case 'recap':
                  unawaited(_runLearningAction(widget.onRecap));
                  break;
                case 'recall':
                  unawaited(_runLearningAction(widget.onRecall));
                  break;
                case 'smaller':
                  _setReadingFontSize(_fontSize - 1);
                  break;
                case 'larger':
                  _setReadingFontSize(_fontSize + 1);
                  break;
              }
            },
            itemBuilder: (_) => [
              if (widget.onListen != null)
                const PopupMenuItem(
                  value: 'listen',
                  child: ListTile(leading: Icon(Icons.headphones_rounded), title: Text('Kaynağı dinle')),
                ),
              if (widget.onRecap != null)
                const PopupMenuItem(
                  value: 'recap',
                  child: ListTile(leading: Icon(Icons.auto_awesome), title: Text('Hızlı özet')),
                ),
              if (widget.onRecall != null)
                const PopupMenuItem(
                  value: 'recall',
                  child: ListTile(
                    leading: Icon(Icons.psychology_alt_outlined),
                    title: Text('Kaynağı kapat ve hatırla'),
                  ),
                ),
              const PopupMenuItem(
                value: 'smaller',
                child: ListTile(leading: Icon(Icons.text_decrease), title: Text('Yazıyı küçült')),
              ),
              const PopupMenuItem(
                value: 'larger',
                child: ListTile(leading: Icon(Icons.text_increase), title: Text('Yazıyı büyüt')),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: (_) => _searchChanged(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Metinde ara',
                    border: const OutlineInputBorder(),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Aramayı temizle',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _searchChanged();
                            },
                          ),
                  ),
                ),
              ),
            if (!_showSearch && query.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  if (!_showSearch) _toggleSearch();
                },
                icon: const Icon(Icons.search),
                label: Text('Arama: $query'),
              ),
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      matches.isEmpty
                          ? 'Eşleşme bulunamadı'
                          : '${matches.length}${matches.length == 2000 ? '+' : ''} eşleşme',
                    ),
                  ),
                ),
              ),
            if (source.isNotEmpty) ...[
              if (restoredFromSavedPosition)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const ValueKey('reader-resume-restored'),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: living ? AtelierStyle.mint : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded, size: 18, color: accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kaldığın yer geri açıldı · %${(widget.initialProgress * 100).round()}',
                              style: theme.textTheme.bodySmall?.copyWith(color: ink, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sourceFitsViewport
                            ? 'Kaynağın tamamı ekranda'
                            : 'Metindeki konum · %${(_readingProgress * 100).round()}',
                        style: TextStyle(color: living ? AtelierStyle.muted : null),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yazıyı küçült',
                      onPressed: _fontSize <= 14 ? null : () => _setReadingFontSize(_fontSize - 1),
                      icon: const Icon(Icons.text_decrease),
                    ),
                    IconButton(
                      tooltip: 'Yazıyı büyüt',
                      onPressed: _fontSize >= 26 ? null : () => _setReadingFontSize(_fontSize + 1),
                      icon: const Icon(Icons.text_increase),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                key: const ValueKey('reader-progress'),
                value: _readingProgress,
                minHeight: living ? 4 : 3,
                color: accent,
                backgroundColor: living ? line : null,
                semanticsLabel: _sourceFitsViewport ? 'Kaynak görünümü, tamamı ekranda' : 'Okuma konumu',
                semanticsValue: '${(_readingProgress * 100).round()}',
              ),
            ],
            Expanded(
              child: source.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_outlined, size: 42, color: accent),
                            const SizedBox(height: 14),
                            Text(
                              'Bu kaynak için okunabilir metin bulunamadı.',
                              style: theme.textTheme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bu ekranda gösterilecek metin yok. Materyale dönüp kaynağın güncel durumunu yeniden açabilir veya güncelleyebilirsin.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (Navigator.of(context).canPop()) ...[
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Materyale dön'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      key: const ValueKey('reader-source-scroll'),
                      controller: _readingScroll,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      children: [
                        if (living)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: paper,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(color: Color(0x1014224A), blurRadius: 24, offset: Offset(0, 10)),
                              ],
                            ),
                            child: Padding(padding: const EdgeInsets.fromLTRB(22, 22, 22, 28), child: article),
                          )
                        else
                          article,
                      ],
                    ),
            ),
            if (_selectedAnchor != null && _selectedText != null)
              Container(
                key: const ValueKey('reader-selection-context'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                decoration: BoxDecoration(
                  color: living ? AtelierStyle.paper : theme.colorScheme.surfaceContainerHighest,
                  border: Border(top: BorderSide(color: line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seçili bölüm · öğrenme kanıtı değil',
                            style: theme.textTheme.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Seçim araçlarını kapat',
                          onPressed: _clearSelectionContext,
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      ],
                    ),
                    Text(
                      _selectedText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: ink),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.onSaveAnnotation != null)
                          OutlinedButton.icon(
                            key: const ValueKey('reader-selection-highlight'),
                            onPressed: _annotationBusy ? null : () => _saveAnnotation(ReaderAnnotationKind.highlight),
                            icon: const Icon(Icons.border_color_outlined),
                            label: const Text('Vurgula'),
                          ),
                        if (widget.onSaveAnnotation != null)
                          OutlinedButton.icon(
                            key: const ValueKey('reader-selection-note'),
                            onPressed: _annotationBusy ? null : _addNoteForSelection,
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text('Not ekle'),
                          ),
                        if (widget.onTutorSelection != null)
                          OutlinedButton.icon(
                            key: const ValueKey('reader-selection-tutor'),
                            onPressed: _annotationBusy
                                ? null
                                : () {
                                    final anchor = _selectedAnchor;
                                    if (anchor != null) widget.onTutorSelection!(anchor);
                                  },
                            icon: const Icon(Icons.forum_outlined),
                            label: const Text('Bu bölümü sor'),
                          ),
                        if (widget.onRecallSelection != null)
                          FilledButton.icon(
                            key: const ValueKey('reader-selection-recall'),
                            onPressed: _annotationBusy
                                ? null
                                : () {
                                    final anchor = _selectedAnchor;
                                    if (anchor != null) widget.onRecallSelection!(anchor);
                                  },
                            icon: const Icon(Icons.psychology_alt_outlined),
                            label: const Text('Bu bölümden hatırla'),
                          ),
                      ],
                    ),
                    if (_annotationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _annotationError!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            if (source.isNotEmpty && (widget.onListen != null || widget.onRecap != null || widget.onRecall != null))
              Semantics(
                container: true,
                label: 'Kaynak açık. Hatırla düğmesi kaynağı kapatıp aktif denemeyi başlatır.',
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AtelierStyle.paper,
                    border: Border(top: BorderSide(color: AtelierStyle.line)),
                    boxShadow: [BoxShadow(color: Color(0x1214224A), blurRadius: 18, offset: Offset(0, -6))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stackActions =
                            constraints.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(16) >= 22;
                        final listenAction = widget.onListen == null
                            ? null
                            : OutlinedButton.icon(
                                onPressed: () => unawaited(_runLearningAction(widget.onListen)),
                                style: living
                                    ? OutlinedButton.styleFrom(
                                        foregroundColor: AtelierStyle.aqua,
                                        backgroundColor: AtelierStyle.aquaSoft,
                                        side: BorderSide.none,
                                        minimumSize: const Size(0, 48),
                                      )
                                    : OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                                icon: const Icon(Icons.headphones_rounded, size: 19),
                                label: const Text('Dinleyerek hazırlan'),
                              );
                        final primaryAction = widget.onRecall != null
                            ? FilledButton.icon(
                                style: living
                                    ? FilledButton.styleFrom(
                                        backgroundColor: AtelierStyle.pulse,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 48),
                                      )
                                    : FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                                onPressed: () => unawaited(_runLearningAction(widget.onRecall)),
                                icon: const Icon(Icons.psychology_alt_outlined),
                                label: const Text('Kaynağı kapat ve hatırla'),
                              )
                            : widget.onRecap != null
                            ? TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: AtelierStyle.pulse),
                                onPressed: () => unawaited(_runLearningAction(widget.onRecap)),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Hızlı özet'),
                              )
                            : null;

                        if (stackActions) {
                          return Column(
                            key: const ValueKey('reader-learning-actions-stacked'),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ?primaryAction,
                              if (primaryAction != null && listenAction != null) const SizedBox(height: 8),
                              ?listenAction,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            ?listenAction,
                            if (listenAction != null && primaryAction != null) const SizedBox(width: 10),
                            if (primaryAction != null) Expanded(child: primaryAction),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
