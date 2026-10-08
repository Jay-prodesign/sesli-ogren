import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'companion_view.dart';

/// One source-led art direction across Reader, Recall and Result.
/// Source/learning models and outcome classification stay canonical.
abstract final class AtelierStyle {
  static const canvas = Color(0xFFF5F7F4);
  static const paper = Color(0xFFFFFDF9);
  static const ink = Color(0xFF15313A);
  static const teal = Color(0xFF0A716A);
  static const muted = Color(0xFF52696B);
  static const line = Color(0xFFD5E3DC);
  static const mint = Color(0xFFE8F3EC);
  static const mark = Color(0xFFE0F0AF);
}

class AtelierWorkspace extends StatelessWidget {
  const AtelierWorkspace({
    required this.material,
    required this.sourceText,
    required this.onRecall,
    required this.onListen,
    required this.onExplain,
    required this.onFocus,
    super.key,
  });

  final MaterialRecord material;
  final String sourceText;
  final VoidCallback onRecall;
  final VoidCallback onListen;
  final VoidCallback onExplain;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('la0040-atelier-workspace'),
    color: AtelierStyle.canvas,
    child: Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(21, 13, 21, 25), children: [
          Text(material.mediaType == SourceMediaType.pdf ? 'PDF KAYNAĞI' : 'KENDİ METNİN',
            style: const TextStyle(color: AtelierStyle.teal, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(material.title, style: const TextStyle(color: AtelierStyle.ink, fontSize: 27, fontWeight: FontWeight.w900, height: 1.14)),
          const SizedBox(height: 17),
          const Divider(color: AtelierStyle.line),
          const SizedBox(height: 14),
          if (sourceText.trim().isEmpty)
            const Text('Bu kaynağın metni henüz okunamıyor.', style: TextStyle(color: AtelierStyle.muted, fontSize: 16))
          else
            SelectableText(sourceText, style: const TextStyle(color: AtelierStyle.ink, fontSize: 17, height: 1.65)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(17, 10, 17, 14),
        decoration: const BoxDecoration(
          color: AtelierStyle.paper, border: Border(top: BorderSide(color: AtelierStyle.line))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Bu kaynakla devam et', style: TextStyle(color: AtelierStyle.ink, fontWeight: FontWeight.w800))),
            TextButton(onPressed: onExplain, child: const Text('Açıkla')),
            IconButton(onPressed: onFocus, tooltip: 'Odaklan', icon: const Icon(Icons.center_focus_strong, color: AtelierStyle.teal)),
          ]),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: onListen,
              icon: const Icon(Icons.headphones_rounded), label: const Text('Dinle'))),
            const SizedBox(width: 9),
            Expanded(child: FilledButton.icon(
              key: const ValueKey('la0040-atelier-workspace-recall'),
              onPressed: onRecall,
              style: FilledButton.styleFrom(backgroundColor: AtelierStyle.teal, foregroundColor: Colors.white),
              icon: const Icon(Icons.psychology_alt_outlined), label: const Text('Hatırla'))),
          ]),
        ]),
      ),
    ]),
  );
}

class AtelierRecall extends StatelessWidget {
  const AtelierRecall({
    required this.prompt,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.onHint,
    required this.onReveal,
    required this.onUnknown,
    this.support,
    this.error,
    super.key,
  });
  final RecallPrompt prompt;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onHint;
  final VoidCallback onReveal;
  final VoidCallback onUnknown;
  final String? support;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('la0040-atelier-recall'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('KAYNAĞA BAKMADAN', style: TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
      const SizedBox(height: 12),
      const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text('Şimdi sen hatırla.', style: TextStyle(color: AtelierStyle.ink, fontSize: 28, height: 1.15, fontWeight: FontWeight.w900))),
        CompanionView(state: CompanionVisualState.think, size: 60),
      ]),
      const SizedBox(height: 17),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(color: AtelierStyle.paper, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AtelierStyle.line)),
        child: Text(prompt.promptText, softWrap: true, style: const TextStyle(color: AtelierStyle.ink,
          fontSize: 22, height: 1.36, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 20),
      const Text('YANITIN', style: TextStyle(color: AtelierStyle.muted, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
      const SizedBox(height: 7),
      TextField(
        key: const ValueKey('la0040-atelier-answer'),
        controller: controller, enabled: !busy, textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          hintText: 'Hatırladığını yaz…', filled: true, fillColor: AtelierStyle.paper,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13))),
      ),
      if (support != null) ...[const SizedBox(height: 12), Text(support!,
        style: const TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w700))],
      if (error != null) ...[const SizedBox(height: 12), Text(error!,
        style: const TextStyle(color: Color(0xFF9A3530), fontWeight: FontWeight.w700))],
      const SizedBox(height: 17),
      SizedBox(width: double.infinity, child: FilledButton(
        key: const ValueKey('la0040-atelier-submit'), onPressed: busy ? null : onSubmit,
        style: FilledButton.styleFrom(backgroundColor: AtelierStyle.teal,
          foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
        child: const Text('Yanıtla'),
      )),
      const SizedBox(height: 9),
      Wrap(spacing: 7, runSpacing: 4, children: [
        OutlinedButton(onPressed: busy ? null : onHint, child: const Text('İpucu')),
        OutlinedButton(onPressed: busy ? null : onReveal, child: const Text('Yanıtı göster')),
        TextButton(onPressed: busy ? null : onUnknown, child: const Text('Bilmiyorum')),
      ]),
    ],
  );
}

class AtelierResult extends StatelessWidget {
  const AtelierResult({required this.result, required this.answerInMemory,
    required this.onContinue, super.key});
  final RecallAttemptResult result;
  final String answerInMemory;
  final VoidCallback onContinue;

  String get _heading => switch (result.evidence.outcome) {
    RecallOutcome.correct when result.evidence.assistance == RecallAssistance.none =>
      'Bir kez bağımsız hatırladın',
    RecallOutcome.helpedCorrect => 'İpucuyla doğru yanıt',
    RecallOutcome.answerExposed => 'Yanıtı gördün',
    RecallOutcome.unknown => 'Bu kez bilmiyorum dedin',
    RecallOutcome.partial => 'Yanıtının bir kısmı eşleşti',
    RecallOutcome.incorrect => 'Bu kez yanıtın eşleşmedi',
    _ => 'Bu denemenin sonucu',
  };

  String get _response {
    if (result.evidence.outcome == RecallOutcome.unknown) return 'Bilmiyorum dedin.';
    if (result.evidence.assistance == RecallAssistance.answerExposed) {
      return 'Yanıt gösterildi; bağımsız hatırlama sayılmadı.';
    }
    return answerInMemory.trim().isEmpty ? 'Yanıt metni bu oturumda yok.' : answerInMemory.trim();
  }

  @override
  Widget build(BuildContext context) {
    final excerpt = result.sourceExcerpt;
    final answer = result.correctAnswer.trim();
    final index = answer.isEmpty ? -1 : excerpt.toLowerCase().indexOf(answer.toLowerCase());
    final spans = <TextSpan>[];
    if (index == -1) {
      spans.add(TextSpan(text: excerpt));
    } else {
      spans.add(TextSpan(text: excerpt.substring(0, index)));
      spans.add(TextSpan(text: excerpt.substring(index, index + answer.length),
        style: const TextStyle(fontWeight: FontWeight.w900, backgroundColor: AtelierStyle.mark)));
      spans.add(TextSpan(text: excerpt.substring(index + answer.length)));
    }
    return Column(
      key: const ValueKey('la0040-atelier-result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KAYNAĞINLA KARŞILAŞTIR', style: TextStyle(color: AtelierStyle.teal,
          fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(_heading, style: const TextStyle(color: AtelierStyle.ink,
            fontWeight: FontWeight.w900, fontSize: 27, height: 1.17))),
          const CompanionView(state: CompanionVisualState.correct, size: 62),
        ]),
        const SizedBox(height: 10),
        Text(result.evidence.outcome == RecallOutcome.correct && result.evidence.assistance == RecallAssistance.none
            ? 'Tek bir bağımsız deneme, henüz ustalık değil.'
            : 'Bu sonuç denemeni ve varsa aldığın yardımı yansıtır.',
          style: const TextStyle(color: AtelierStyle.muted, fontSize: 14, height: 1.42)),
        const SizedBox(height: 22),
        const Text('SENİN DENEMEN', style: TextStyle(color: AtelierStyle.muted, fontSize: 11,
          fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: AtelierStyle.mint, borderRadius: BorderRadius.circular(14)),
          child: Text(_response, style: const TextStyle(color: AtelierStyle.ink,
            fontSize: 16, height: 1.45, fontWeight: FontWeight.w700))),
        const SizedBox(height: 22),
        const Text('KAYNAĞINDAKİ DOĞRU İFADE', style: TextStyle(color: AtelierStyle.teal,
          fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 9),
        Text(result.correctAnswer, style: const TextStyle(color: AtelierStyle.ink,
          fontSize: 23, fontWeight: FontWeight.w900, height: 1.24)),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AtelierStyle.paper,
            border: Border.all(color: AtelierStyle.line), borderRadius: BorderRadius.circular(14)),
          child: Text.rich(TextSpan(children: spans), style: const TextStyle(
            color: AtelierStyle.ink, fontSize: 16, height: 1.55))),
        const SizedBox(height: 22),
        const Text('SIRADAKİ GERÇEK ADIM', style: TextStyle(color: AtelierStyle.teal,
          fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(result.nextAction.reasonText, style: const TextStyle(color: AtelierStyle.ink,
          fontSize: 16, height: 1.44, fontWeight: FontWeight.w700)),
        const SizedBox(height: 19),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          key: const ValueKey('la0040-atelier-next'), onPressed: onContinue,
          style: FilledButton.styleFrom(backgroundColor: AtelierStyle.teal,
            foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Sıradaki adıma geç'))),
      ],
    );
  }
}
