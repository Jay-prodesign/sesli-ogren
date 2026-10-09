import 'package:flutter/material.dart';

/// Read the complete locally extracted source without sending it to a model.
class SourceReaderScreen extends StatefulWidget {
  const SourceReaderScreen({required this.title, required this.sourceText, this.onListen, this.onRecap, this.onRecall, super.key});

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
  double _fontSize = 17;
  bool _showSearch = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final source = widget.sourceText.trim();
    final lower = source.toLowerCase();
    final needle = query.toLowerCase();
    final matches = <int>[];
    if (needle.isNotEmpty) {
      var from = 0;
      while (from < lower.length && matches.length < 2000) {
        final at = lower.indexOf(needle, from);
        if (at < 0) break;
        matches.add(at);
        from = at + needle.length;
      }
    }

    final spans = <TextSpan>[];
    if (matches.isEmpty) {
      spans.add(TextSpan(text: source));
    } else {
      var cursor = 0;
      for (final at in matches) {
        if (at > cursor) spans.add(TextSpan(text: source.substring(cursor, at)));
        spans.add(TextSpan(
          text: source.substring(at, at + needle.length),
          style: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ));
        cursor = at + needle.length;
      }
      if (cursor < source.length) spans.add(TextSpan(text: source.substring(cursor)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Metinde ara',
            onPressed: () => setState(() => _showSearch = !_showSearch),
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
                  setState(() => _fontSize = (_fontSize - 1).clamp(14.0, 26.0).toDouble());
                  break;
                case 'larger':
                  setState(() => _fontSize = (_fontSize + 1).clamp(14.0, 26.0).toDouble());
                  break;
              }
            },
            itemBuilder: (_) => [
              if (widget.onListen != null)
                const PopupMenuItem(value: 'listen', child: ListTile(leading: Icon(Icons.headphones_rounded), title: Text('Kaynağı dinle'))),
              if (widget.onRecap != null)
                const PopupMenuItem(value: 'recap', child: ListTile(leading: Icon(Icons.auto_awesome), title: Text('Hızlı özet'))),
              if (widget.onRecall != null)
                const PopupMenuItem(value: 'recall', child: ListTile(leading: Icon(Icons.psychology_alt_outlined), title: Text('Hatırlama çalışması'))),
              const PopupMenuItem(value: 'smaller', child: ListTile(leading: Icon(Icons.text_decrease), title: Text('Yazıyı küçült'))),
              const PopupMenuItem(value: 'larger', child: ListTile(leading: Icon(Icons.text_increase), title: Text('Yazıyı büyüt'))),
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
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Metinde ara',
                    border: const OutlineInputBorder(),
                    suffixIcon: query.isEmpty ? null : IconButton(
                      tooltip: 'Aramayı temizle',
                      icon: const Icon(Icons.close),
                      onPressed: () { _search.clear(); setState(() {}); },
                    ),
                  ),
                ),
              ),
            if (!_showSearch && query.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _showSearch = true),
                icon: const Icon(Icons.search),
                label: Text('Arama: $query'),
              ),
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(matches.isEmpty ? 'Eşleşme bulunamadı' : '${matches.length}${matches.length == 2000 ? '+' : ''} eşleşme'),
                ),
              ),
            if (source.isNotEmpty && widget.onRecall != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: FilledButton.icon(
                  onPressed: widget.onRecall,
                  icon: const Icon(Icons.psychology_alt_outlined),
                  label: const Text('Okuduklarını hatırla'),
                ),
              ),
            Expanded(
              child: source.isEmpty
                  ? const Center(child: Text('Bu kaynak için okunabilir metin bulunamadı.'))
                  : SelectionArea(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                        children: [
                          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: _fontSize,
                                height: 1.65,
                              ),
                              children: spans,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
