import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../learning/focus_help_gateway.dart';
import 'app_runtime.dart';

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

  Future<void> request(FocusHelpKind kind) async {
    setState(() {
      busy = true;
      help = null;
    });
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Odaklan')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Kısa odak oturumu', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Bu oturum güncel kaynağa bağlıdır. Yardım almak tek başına öğrenme kanıtı oluşturmaz.'),
        const SizedBox(height: 20),
        const Text('1 · Konuyu yeniden kur'),
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Text(widget.sourceText)),
        ),
        const SizedBox(height: 20),
        const Text('2 · Takıldığın noktayı sor'),
        TextField(controller: question, maxLength: 600, maxLines: 4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => request(FocusHelpKind.hint),
                child: const Text('İpucu ver'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : () => request(FocusHelpKind.directExplanation),
                child: const Text('Doğrudan açıkla'),
              ),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (help case final FocusHelpReady ready)
          Text(ready.matches(widget.source.identity) ? ready.text : 'Kaynak değişti; eski yanıtı göstermiyoruz.'),
        if (help case final FocusHelpUnavailable unavailable) Text(unavailable.reason),
        const SizedBox(height: 20),
        const Text('3 · Hatırla veya kendi cümlelerinle anlat ile aktif olarak doğrula.'),
      ],
    ),
  );
}
