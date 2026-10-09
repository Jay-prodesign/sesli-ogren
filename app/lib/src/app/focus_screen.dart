import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../learning/focus_help_gateway.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'explain_screen.dart';
import 'companion_view.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({required this.runtime, required this.source, required this.sourceText, super.key});
  final AppRuntime runtime;
  final SourceVersionRecord source;
  final String sourceText;
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final question = TextEditingController();
  FocusHelpResult? help;
  bool busy = false;

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> _openDirectExplanation() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ExplainScreen(runtime: widget.runtime, source: widget.source),
    ),
  );

  FocusHelpResult _localSourceHint() {
    final source = widget.sourceText.trim();
    final learnerQuestion = question.text.trim();
    if (learnerQuestion.isEmpty) {
      return const FocusHelpUnavailable('İpucu için takıldığın noktayı kısa bir cümleyle yaz.');
    }
    if (source.isEmpty) {
      return const FocusHelpUnavailable('Güncel kaynak metni olmadığı için güvenilir ipucu veremiyoruz.');
    }

    final stopWords = <String>{
      'acaba',
      'ama',
      'bana',
      'bunu',
      'burada',
      'daha',
      'diye',
      'gibi',
      'hangi',
      'icin',
      'için',
      'kadar',
      'kim',
      'mi',
      'mı',
      'mu',
      'mü',
      'nasil',
      'nasıl',
      'neden',
      'nedir',
      'olan',
      'olarak',
      've',
      'veya',
      'şey',
    };
    final terms = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü0-9]+')
        .allMatches(learnerQuestion.toLowerCase())
        .map((match) => match.group(0)!)
        .where((term) => term.length >= 4 && !stopWords.contains(term))
        .toSet();

    if (terms.isEmpty) {
      return const FocusHelpUnavailable(
        'Sorunu biraz daha somutlaştır. Kaynakta geçen bir kavramı veya terimi yazarsan ilgili bölümü gösterebiliriz.',
      );
    }

    final segments = source
        .split(RegExp(r'(?:[.!?]+\s+)|(?:\n+)'))
        .map((segment) => segment.trim())
        .where((segment) => segment.length >= 12)
        .toList(growable: false);

    String? best;
    var bestScore = 0;
    for (final segment in segments) {
      final normalized = segment.toLowerCase();
      final score = terms.where(normalized.contains).length;
      if (score > bestScore) {
        best = segment;
        bestScore = score;
      }
    }

    if (best == null || bestScore == 0) {
      return const FocusHelpUnavailable(
        'Soruna kaynakta güvenle bağlayabildiğimiz bir bölüm bulamadık. Sorunda kaynaktaki anahtar terimlerden birini kullan.',
      );
    }

    final excerpt = best.length <= 280 ? best : '${best.substring(0, 277).trimRight()}…';
    return FocusHelpReady(
      sourceVersionId: widget.source.identity.sourceVersionId,
      sourceContentDigest: widget.source.identity.contentDigest,
      text: 'Kaynak ipucu: “$excerpt”\n\nBu bölümdeki ilişkiyi kendi cümlelerinle yeniden kurmayı dene.',
      executionRef: 'local:source-cue-v1',
    );
  }

  Future<void> request(FocusHelpKind kind) async {
    setState(() {
      busy = true;
      help = null;
    });

    if (kind == FocusHelpKind.hint && widget.runtime.focusHelp is UnavailableFocusHelpGateway) {
      final result = _localSourceHint();
      if (!mounted) return;
      setState(() {
        busy = false;
        help = result;
      });
      return;
    }

    final result = await widget.runtime.focusHelp.help(
      FocusHelpRequest(
        materialId: widget.source.identity.materialId,
        sourceVersionId: widget.source.identity.sourceVersionId,
        sourceContentDigest: widget.source.identity.contentDigest,
        kind: kind,
        outputLocale: 'tr-TR',
        learnerQuestion: question.text.trim().isEmpty ? null : question.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() {
      busy = false;
      help = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readyHelp = help is FocusHelpReady ? help as FocusHelpReady : null;
    final unavailable = help is FocusHelpUnavailable ? help as FocusHelpUnavailable : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Odaklan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: AppPalette.momentum, borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CompanionView(state: busy ? CompanionVisualState.think : CompanionVisualState.idle, size: 56),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9D7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        child: Text(
                          'KISA ODAK',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppPalette.momentumInk,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Kısa odak oturumu',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(color: AppPalette.signalSoft, borderRadius: BorderRadius.circular(14)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Text('Bu oturum güncel kaynağa bağlıdır. Yardım almak tek başına öğrenme kanıtı oluşturmaz.'),
            ),
          ),
          const SizedBox(height: 22),
          Text('1 · Konuyu yeniden kur', style: theme.textTheme.titleMedium),
          const SizedBox(height: 9),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.article_outlined, color: AppPalette.signal, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        'Kaynak metni',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppPalette.signal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(widget.sourceText, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('2 · Takıldığın noktayı sor', style: theme.textTheme.titleMedium),
          const SizedBox(height: 9),
          TextField(
            controller: question,
            maxLength: 600,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Neyi netleştirmek istiyorsun?'),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => request(FocusHelpKind.hint),
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: const Text('İpucu ver'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : _openDirectExplanation,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Doğrudan açıkla'),
                ),
              ),
            ],
          ),
          if (busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
          if (readyHelp != null) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Text(
                  readyHelp.matches(widget.source.identity)
                      ? readyHelp.text
                      : 'Kaynak değişti; eski yanıtı göstermiyoruz.',
                ),
              ),
            ),
          ],
          if (unavailable != null) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(color: AppPalette.attentionSoft, borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppPalette.attention, size: 20),
                    const SizedBox(width: 9),
                    Expanded(child: Text(unavailable.reason)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          DecoratedBox(
            decoration: BoxDecoration(color: AppPalette.primaryDark, borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(15),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '3 · Hatırla veya kendi cümlelerinle anlat ile aktif olarak doğrula.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
