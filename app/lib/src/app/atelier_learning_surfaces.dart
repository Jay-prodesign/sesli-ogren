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
    child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(21, 13, 21, 25),
            children: [
              Text(
                material.mediaType == SourceMediaType.pdf ? 'PDF KAYNAĞI' : 'KENDİ METNİN',
                style: const TextStyle(
                  color: AtelierStyle.teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                material.title,
                style: const TextStyle(
                  color: AtelierStyle.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.14,
                ),
              ),
              const SizedBox(height: 17),
              if (sourceText.trim().isNotEmpty) ...[
                Container(
                  key: const ValueKey('la0040-reader-companion-scene'),
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F2EA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      CompanionView(state: CompanionVisualState.listen, size: 96),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BİRLİKTE KEŞFEDELİM',
                              style: TextStyle(
                                color: AtelierStyle.teal,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Önce oku, sonra kendi sözlerinle anlat.',
                              style: TextStyle(
                                color: AtelierStyle.ink,
                                fontSize: 17,
                                height: 1.24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                  decoration: BoxDecoration(color: AtelierStyle.mint, borderRadius: BorderRadius.circular(14)),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: AtelierStyle.teal, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Okurken bir şeyi yakala',
                              style: TextStyle(color: AtelierStyle.ink, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Bu metnin en önemli fikri ne? Birazdan kaynağı kapatıp kendi sözlerinle hatırlayacaksın.',
                              style: TextStyle(color: AtelierStyle.muted, fontSize: 14, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              const Divider(color: AtelierStyle.line),
              const SizedBox(height: 14),
              if (sourceText.trim().isEmpty)
                const Text(
                  'Bu kaynağın metni henüz okunamıyor.',
                  style: TextStyle(color: AtelierStyle.muted, fontSize: 16),
                )
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
                  decoration: const BoxDecoration(
                    color: AtelierStyle.paper,
                    border: Border(left: BorderSide(color: AtelierStyle.teal, width: 3)),
                    boxShadow: [BoxShadow(color: Color(0x0B15313A), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_stories_outlined, color: AtelierStyle.teal, size: 17),
                          SizedBox(width: 8),
                          Text(
                            'ORİJİNAL KAYNAĞIN',
                            style: TextStyle(
                              color: AtelierStyle.teal,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      SelectableText(
                        sourceText,
                        style: const TextStyle(color: AtelierStyle.ink, fontSize: 18, height: 1.65),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(17, 10, 17, 14),
          decoration: const BoxDecoration(
            color: AtelierStyle.ink,
            borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Kaynağınla devam et',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: onExplain,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Açıkla'),
                  ),
                  IconButton(
                    onPressed: onFocus,
                    tooltip: 'Odaklan',
                    icon: const Icon(Icons.center_focus_strong, color: Colors.white),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onListen,
                      icon: const Icon(Icons.headphones_rounded),
                      label: const Text('Dinle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF8EA9A3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('la0040-atelier-workspace-recall'),
                      onPressed: onRecall,
                      style: FilledButton.styleFrom(
                        backgroundColor: AtelierStyle.mark,
                        foregroundColor: AtelierStyle.ink,
                      ),
                      icon: const Icon(Icons.psychology_alt_outlined),
                      label: const Text('Hatırla'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
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
      const Text(
        'KAYNAK GİZLENDİ · ŞİMDİ SEN',
        style: TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
      ),
      const SizedBox(height: 12),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Hatırlama sırası sende.',
              style: TextStyle(color: AtelierStyle.ink, fontSize: 28, height: 1.15, fontWeight: FontWeight.w900),
            ),
          ),
          CompanionView(state: CompanionVisualState.think, size: 128),
        ],
      ),
      const SizedBox(height: 17),
      Container(
        key: const ValueKey('la0040-recall-companion-guidance'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AtelierStyle.mint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AtelierStyle.line),
        ),
        child: const Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: AtelierStyle.teal, size: 21),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                'D/Knot: Acele etme. Hatırladığın kadarıyla anlat; takıldığında ipucu isteyebilirsin.',
                style: TextStyle(color: AtelierStyle.ink, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 15),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(19, 19, 19, 23),
        decoration: BoxDecoration(color: AtelierStyle.ink, borderRadius: BorderRadius.circular(21)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.visibility_off_outlined, color: AtelierStyle.mark, size: 17),
                SizedBox(width: 8),
                Text(
                  'KAYNAĞA BAKMADAN',
                  style: TextStyle(
                    color: AtelierStyle.mark,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            Text(
              prompt.promptText,
              softWrap: true,
              style: const TextStyle(color: Colors.white, fontSize: 23, height: 1.34, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AtelierStyle.teal, size: 17),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Kaynak yanıtını gönderene kadar kapalı kalacak.',
              style: TextStyle(color: AtelierStyle.muted, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const Text(
        'YANITIN',
        style: TextStyle(color: AtelierStyle.muted, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
      ),
      const SizedBox(height: 7),
      TextField(
        key: const ValueKey('la0040-atelier-answer'),
        controller: controller,
        enabled: !busy,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Kaynağa bakmadan hatırladığını kendi cümlelerinle yaz…',
          filled: true,
          fillColor: AtelierStyle.paper,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      if (support != null) ...[
        const SizedBox(height: 12),
        Text(
          support!,
          style: const TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w700),
        ),
      ],
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(
          error!,
          style: const TextStyle(color: Color(0xFF9A3530), fontWeight: FontWeight.w700),
        ),
      ],
      const SizedBox(height: 17),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('la0040-atelier-submit'),
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: AtelierStyle.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Yanıtı karşılaştır'),
        ),
      ),
      const SizedBox(height: 9),
      Wrap(
        spacing: 7,
        runSpacing: 4,
        children: [
          OutlinedButton(onPressed: busy ? null : onHint, child: const Text('İpucu')),
          OutlinedButton(onPressed: busy ? null : onReveal, child: const Text('Yanıtı göster')),
          TextButton(onPressed: busy ? null : onUnknown, child: const Text('Bilmiyorum')),
        ],
      ),
    ],
  );
}

class AtelierResult extends StatelessWidget {
  const AtelierResult({required this.result, required this.answerInMemory, required this.onContinue, super.key});
  final RecallAttemptResult result;
  final String answerInMemory;
  final VoidCallback onContinue;

  String get _heading => switch (result.evidence.outcome) {
    RecallOutcome.correct when result.evidence.assistance == RecallAssistance.none => 'Bir kez bağımsız hatırladın',
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
    final independent =
        result.evidence.outcome == RecallOutcome.correct && result.evidence.assistance == RecallAssistance.none;
    final assisted = result.evidence.outcome == RecallOutcome.helpedCorrect;
    final responseColor = independent
        ? AtelierStyle.mint
        : assisted
        ? const Color(0xFFFFF1D9)
        : const Color(0xFFF1F0EC);
    final spans = <TextSpan>[];
    if (index == -1) {
      spans.add(TextSpan(text: excerpt));
    } else {
      spans.add(TextSpan(text: excerpt.substring(0, index)));
      spans.add(
        TextSpan(
          text: excerpt.substring(index, index + answer.length),
          style: const TextStyle(color: AtelierStyle.mark, fontWeight: FontWeight.w900),
        ),
      );
      spans.add(TextSpan(text: excerpt.substring(index + answer.length)));
    }
    return Column(
      key: const ValueKey('la0040-atelier-result'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KAYNAĞINLA KARŞILAŞTIR',
          style: TextStyle(color: AtelierStyle.teal, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _heading,
                style: const TextStyle(
                  color: AtelierStyle.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 27,
                  height: 1.17,
                ),
              ),
            ),
            CompanionView(
              state:
                  result.evidence.outcome == RecallOutcome.correct &&
                      result.evidence.assistance == RecallAssistance.none
                  ? CompanionVisualState.success
                  : result.evidence.outcome == RecallOutcome.helpedCorrect
                  ? CompanionVisualState.correct
                  : CompanionVisualState.think,
              size: 128,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          result.evidence.outcome == RecallOutcome.correct && result.evidence.assistance == RecallAssistance.none
              ? 'Tek bir bağımsız deneme, henüz ustalık değil.'
              : 'Bu sonuç denemeni ve varsa aldığın yardımı yansıtır.',
          style: const TextStyle(color: AtelierStyle.muted, fontSize: 14, height: 1.42),
        ),
        const SizedBox(height: 13),
        Container(
          key: const ValueKey('la0040-result-companion-reflection'),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(color: AtelierStyle.mint, borderRadius: BorderRadius.circular(17)),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: AtelierStyle.teal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  independent
                      ? 'D/Knot: Kendi başına hatırladın. Bunu kalıcılaştırmak için daha sonra yeniden dene.'
                      : assisted
                      ? 'D/Knot: İpucundan yararlandın. Şimdi kaynağı görüp sonra yeniden denemek iyi olabilir.'
                      : 'D/Knot: Bu deneme bize sonraki çalışmanda nereye odaklanacağını gösteriyor.',
                  style: const TextStyle(color: AtelierStyle.ink, fontSize: 13, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        const Text(
          'ÖNCE SENİN YANITIN',
          style: TextStyle(color: AtelierStyle.muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: responseColor,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: independent
                    ? AtelierStyle.teal
                    : assisted
                    ? const Color(0xFFC48B33)
                    : AtelierStyle.muted,
                width: 4,
              ),
            ),
          ),
          child: Text(
            _response,
            style: const TextStyle(color: AtelierStyle.ink, fontSize: 16, height: 1.45, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 13),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_downward_rounded, color: AtelierStyle.teal, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'ŞİMDİ KAYNAĞINDAKİ KANIT',
                  style: TextStyle(
                    color: AtelierStyle.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          key: const ValueKey('la0040-source-evidence-reveal'),
          tween: Tween<double>(begin: 0, end: 1),
          duration:
              ((MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
                  (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false))
              ? Duration.zero
              : const Duration(milliseconds: 240),
          builder: (context, progress, child) => Opacity(
            opacity: progress,
            child: Transform.translate(offset: Offset(0, 12 * (1 - progress)), child: child),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 21, 20, 23),
            decoration: BoxDecoration(color: AtelierStyle.ink, borderRadius: BorderRadius.circular(21)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.find_in_page_outlined, color: AtelierStyle.mark, size: 20),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'KAYNAKTAKİ DOĞRU İFADE',
                        style: TextStyle(
                          color: AtelierStyle.mark,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  result.correctAnswer,
                  style: const TextStyle(color: Colors.white, fontSize: 25, height: 1.2, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 15),
                const Divider(color: Color(0xFF486068), height: 1),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(children: spans),
                  style: const TextStyle(color: Color(0xFFE4EDEC), fontSize: 16, height: 1.54),
                ),
                if (index < 0) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Bu alıntıda doğru ifadeye birebir vurgu bulunamadı.',
                    style: TextStyle(color: Color(0xFFC7D6D4), fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Icon(Icons.route_outlined, color: AtelierStyle.teal, size: 20),
            SizedBox(width: 8),
            Text(
              'ÖĞRENME YOLCULUĞUN',
              style: TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          independent
              ? 'Bir kez kendi başına hatırladın. Bilginin kalıcı olup olmadığını sonraki denemeler gösterecek.'
              : 'Bu deneme kaydedildi. Kaynağı ve kendi yanıtını karşılaştırarak bir sonraki adımına hazırlan.',
          style: const TextStyle(color: AtelierStyle.muted, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 13),
        const Text(
          'SIRADAKİ GERÇEK ADIM',
          style: TextStyle(color: AtelierStyle.teal, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Text(
          result.nextAction.reasonText,
          style: const TextStyle(color: AtelierStyle.ink, fontSize: 16, height: 1.44, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('la0040-atelier-next'),
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AtelierStyle.teal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Sıradaki adıma geç'),
          ),
        ),
      ],
    );
  }
}
