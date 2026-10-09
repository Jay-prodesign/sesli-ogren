import 'package:flutter/material.dart';

/// Read the complete locally extracted source without sending it to a model.
class SourceReaderScreen extends StatefulWidget {
  const SourceReaderScreen({required this.title, required this.sourceText, super.key});

  final String title;
  final String sourceText;

  @override
  State<SourceReaderScreen> createState() => _SourceReaderScreenState();
}

class _SourceReaderScreenState extends State<SourceReaderScreen> {
  final TextEditingController _search = TextEditingController();
  double _fontSize = 17;

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
            tooltip: 'Yazıyı küçült',
            onPressed: _fontSize <= 14 ? null : () => setState(() => _fontSize -= 1),
            icon: const Icon(Icons.text_decrease),
          ),
          IconButton(
            tooltip: 'Yazıyı büyüt',
            onPressed: _fontSize >= 26 ? null : () => setState(() => _fontSize += 1),
            icon: const Icon(Icons.text_increase),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
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
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(matches.isEmpty ? 'Eşleşme bulunamadı' : '${matches.length}${matches.length == 2000 ? '+' : ''} eşleşme'),
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
