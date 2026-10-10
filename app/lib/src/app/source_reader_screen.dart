import 'package:flutter/material.dart';

import 'atelier_learning_surfaces.dart';
import 'living_study_desk_home.dart';
import 'source_text_matching.dart';

/// Read the complete locally extracted source without sending it to a model.
class SourceReaderScreen extends StatefulWidget {
  const SourceReaderScreen({
    required this.title,
    required this.sourceText,
    this.onListen,
    this.onRecap,
    this.onRecall,
    super.key,
  });

  final String title;
  final String sourceText;
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
  double _fontSize = 17;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _readingScroll.addListener(_updateReadingProgress);
    _scheduleReadingProgressUpdate();
  }

  @override
  void didUpdateWidget(covariant SourceReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceText != widget.sourceText) {
      _readingProgress = 0;
      _scheduleReadingProgressUpdate();
    }
  }

  @override
  void dispose() {
    _readingScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _scheduleReadingProgressUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateReadingProgress();
    });
  }

  void _updateReadingProgress() {
    if (!_readingScroll.hasClients) return;
    final position = _readingScroll.position;
    final max = position.maxScrollExtent;
    final progress = max <= 0 ? 1.0 : (position.pixels / max).clamp(0.0, 1.0);
    if ((progress - _readingProgress).abs() >= 0.01 || progress == 0 || progress == 1.0) {
      setState(() => _readingProgress = progress);
    }
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

    final spans = <TextSpan>[];
    if (matches.isEmpty) {
      spans.add(TextSpan(text: source));
    } else {
      var cursor = 0;
      for (final match in matches) {
        if (match.start > cursor) spans.add(TextSpan(text: source.substring(cursor, match.start)));
        spans.add(
          TextSpan(
            text: source.substring(match.start, match.end),
            style: TextStyle(
              backgroundColor: living ? AtelierStyle.mark : theme.colorScheme.tertiaryContainer,
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        cursor = match.end;
      }
      if (cursor < source.length) spans.add(TextSpan(text: source.substring(cursor)));
    }

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
        if (living) ...[
          const SizedBox(height: 14),
          const AtelierLearningRail(phase: AtelierLearningPhase.source),
        ],
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(color: ink, fontSize: _fontSize, height: 1.65),
            children: spans,
          ),
        ),
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
                  widget.onListen?.call();
                  break;
                case 'recap':
                  widget.onRecap?.call();
                  break;
                case 'recall':
                  widget.onRecall?.call();
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
                  child: ListTile(leading: Icon(Icons.psychology_alt_outlined), title: Text('Hatırlama çalışması')),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Metindeki konum · %${(_readingProgress * 100).round()}',
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
                value: _readingProgress,
                minHeight: living ? 4 : 3,
                color: accent,
                backgroundColor: living ? line : null,
                semanticsLabel: 'Okuma ilerlemesi',
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
                  : SelectionArea(
                      child: ListView(
                        controller: _readingScroll,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        children: [
                          if (living)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: paper,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: line),
                              ),
                              child: Padding(padding: const EdgeInsets.fromLTRB(22, 22, 22, 28), child: article),
                            )
                          else
                            article,
                        ],
                      ),
                    ),
            ),
            if (source.isNotEmpty && (widget.onListen != null || widget.onRecap != null || widget.onRecall != null))
              Semantics(
                container: true,
                label: 'Kaynak açık. Hatırla düğmesi kaynağı kapatıp aktif denemeyi başlatır.',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: paper,
                    border: Border(top: BorderSide(color: line)),
                  ),
                  child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      if (widget.onListen != null)
                        IconButton.filledTonal(
                          tooltip: 'Kaynağı dinle',
                          onPressed: widget.onListen,
                          style: living
                              ? IconButton.styleFrom(
                                  foregroundColor: AtelierStyle.teal,
                                  backgroundColor: AtelierStyle.mint,
                                )
                              : null,
                          icon: const Icon(Icons.headphones_rounded),
                        ),
                      if (widget.onListen != null && (widget.onRecap != null || widget.onRecall != null))
                        const SizedBox(width: 8),
                      if (widget.onRecap != null)
                        IconButton.filledTonal(
                          tooltip: 'Hızlı özet',
                          onPressed: widget.onRecap,
                          style: living
                              ? IconButton.styleFrom(
                                  foregroundColor: AtelierStyle.teal,
                                  backgroundColor: AtelierStyle.mint,
                                )
                              : null,
                          icon: const Icon(Icons.auto_awesome),
                        ),
                      if (widget.onRecap != null && widget.onRecall != null) const SizedBox(width: 10),
                      if (widget.onRecall != null)
                        Expanded(
                          child: FilledButton.icon(
                            style: living
                                ? FilledButton.styleFrom(
                                    backgroundColor: AtelierStyle.ink,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                  )
                                : FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            onPressed: widget.onRecall,
                            icon: const Icon(Icons.psychology_alt_outlined),
                            label: const Text('Hatırla'),
                          ),
                        ),
                    ],
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
