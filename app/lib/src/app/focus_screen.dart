import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../generation/supabase_source_summary_gateway.dart';
import '../learning/focus_help_gateway.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'companion_view.dart';
import 'explain_back_screen.dart';
import 'explain_screen.dart';
import 'learning_slice_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({
    required this.runtime,
    required this.source,
    required this.sourceText,
    this.sourceGateway = const SupabaseSourceSummaryGateway(),
    super.key,
  });

  final AppRuntime runtime;
  final SourceVersionRecord source;
  final String sourceText;
  final SupabaseSourceSummaryGateway sourceGateway;

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

  Future<void> _openRecall() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => LearningSliceScreen(runtime: widget.runtime, materialId: widget.source.identity.materialId),
    ),
  );

  Future<void> _openExplainBack() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ExplainBackScreen(runtime: widget.runtime, source: widget.source),
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
      sourceCues: [excerpt],
      executionRef: 'local:source-cue-v1',
    );
  }

  Future<FocusHelpResult> _requestServerHelp(FocusHelpKind kind) async {
    final learnerQuestion = question.text.trim();
    if (learnerQuestion.length < 2) {
      return const FocusHelpUnavailable('Takıldığın noktayı kısa ve somut bir soruyla yaz.');
    }

    final currentSource = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: widget.source.identity.materialId,
    );
    if (currentSource == null ||
        currentSource.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
        currentSource.identity.contentDigest != widget.source.identity.contentDigest) {
      return const FocusHelpUnavailable('Kaynak değişti. Güncel materyalden yeniden Odaklan aç.');
    }

    final material = await widget.runtime.store.material(
      learner: widget.runtime.learner,
      materialId: widget.source.identity.materialId,
    );
    final extracted = await widget.runtime.store.extractedContentForSource(
      learner: widget.runtime.learner,
      sourceVersionId: widget.source.identity.sourceVersionId,
    );
    if (material == null ||
        extracted == null ||
        !extracted.isValid ||
        extracted.sourceContentDigest != widget.source.identity.contentDigest) {
      return const FocusHelpUnavailable('Güncel kaynak güvenilir biçimde okunamıyor.');
    }

    final normalizedSource = extracted.normalizedText.trim();
    if (normalizedSource.isEmpty) {
      return const FocusHelpUnavailable('Güncel kaynak metni boş.');
    }
    final groundingContentHash = sha256.convert(utf8.encode(normalizedSource)).toString();

    var serverMaterialId = await widget.runtime.store.summaryServerMaterialId(
      learner: widget.runtime.learner,
      materialId: widget.source.identity.materialId,
      sourceVersionId: widget.source.identity.sourceVersionId,
    );

    if (serverMaterialId == null) {
      final staleServerMaterialId = await widget.runtime.store.summaryServerMaterialId(
        learner: widget.runtime.learner,
        materialId: widget.source.identity.materialId,
      );
      if (staleServerMaterialId != null) {
        final removed = await widget.sourceGateway.deleteServerMaterial(staleServerMaterialId);
        if (!removed) {
          return const FocusHelpUnavailable('Önceki kaynak kopyası güvenli biçimde temizlenemedi.');
        }
        await widget.runtime.store.clearSummaryJob(
          learner: widget.runtime.learner,
          materialId: widget.source.identity.materialId,
        );
        await widget.runtime.store.clearServerMaterialBinding(
          learner: widget.runtime.learner,
          materialId: widget.source.identity.materialId,
        );
      }

      serverMaterialId = await widget.sourceGateway.ensureServerMaterial(
        source: SourceIngestResult(material: material, sourceVersion: currentSource, extractedContent: extracted),
      );

      final sourceAfterBinding = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: widget.source.identity.materialId,
      );
      if (sourceAfterBinding?.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
          sourceAfterBinding?.identity.contentDigest != widget.source.identity.contentDigest) {
        await widget.sourceGateway.deleteServerMaterial(serverMaterialId);
        return const FocusHelpUnavailable('Kaynak değişti; eski sürüm için AI yardımı göstermiyoruz.');
      }

      await widget.runtime.store.saveServerMaterialBinding(
        learner: widget.runtime.learner,
        materialId: widget.source.identity.materialId,
        sourceVersionId: widget.source.identity.sourceVersionId,
        serverMaterialId: serverMaterialId,
      );
    }

    final result = await widget.runtime.focusHelp.help(
      FocusHelpRequest(
        materialId: widget.source.identity.materialId,
        sourceVersionId: widget.source.identity.sourceVersionId,
        sourceContentDigest: widget.source.identity.contentDigest,
        kind: kind,
        outputLocale: 'tr-TR',
        learnerQuestion: learnerQuestion,
        serverMaterialId: serverMaterialId,
        groundingContentHash: groundingContentHash,
      ),
    );

    final sourceAfterHelp = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: widget.source.identity.materialId,
    );
    if (sourceAfterHelp?.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
        sourceAfterHelp?.identity.contentDigest != widget.source.identity.contentDigest) {
      return const FocusHelpUnavailable('Kaynak değişti; eski sürüme ait yanıtı göstermiyoruz.');
    }
    return result;
  }

  Future<FocusHelpResult> _localHintForCurrentSource() async {
    final currentSource = await widget.runtime.store.currentSourceVersion(
      learner: widget.runtime.learner,
      materialId: widget.source.identity.materialId,
    );
    if (currentSource == null ||
        currentSource.identity.sourceVersionId != widget.source.identity.sourceVersionId ||
        currentSource.identity.contentDigest != widget.source.identity.contentDigest) {
      return const FocusHelpUnavailable('Kaynak değişti. Güncel materyalden yeniden Odaklan aç.');
    }
    return _localSourceHint();
  }

  Future<void> request(FocusHelpKind kind) async {
    if (busy) return;
    setState(() {
      busy = true;
      help = null;
    });

    if (widget.runtime.focusHelp is UnavailableFocusHelpGateway) {
      if (kind == FocusHelpKind.hint) {
        final result = _localSourceHint();
        if (!mounted) return;
        setState(() {
          busy = false;
          help = result;
        });
        return;
      }
      if (mounted) setState(() => busy = false);
      await _openDirectExplanation();
      return;
    }

    FocusHelpResult result;
    try {
      result = await _requestServerHelp(kind);
    } catch (_) {
      result = const FocusHelpUnavailable('Kaynağa bağlı AI yardımına şu anda ulaşılamıyor.');
    }
    if (kind == FocusHelpKind.hint && result is FocusHelpUnavailable) {
      result = await _localHintForCurrentSource();
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      help = result is FocusHelpReady && !result.matches(widget.source.identity)
          ? const FocusHelpUnavailable('Kaynak değişti; eski yanıtı göstermiyoruz.')
          : result;
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
                          'KISA ODAK · 3 ADIM',
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
                      'Kaynağı netleştir, sonra aktif olarak doğrula.',
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
            enabled: !busy,
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
                  onPressed: busy ? null : () => request(FocusHelpKind.directExplanation),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Sorumu açıkla'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      readyHelp.matches(widget.source.identity)
                          ? readyHelp.text
                          : 'Kaynak değişti; eski yanıtı göstermiyoruz.',
                    ),
                    if (readyHelp.sourceCues.isNotEmpty && readyHelp.matches(widget.source.identity)) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Kaynak dayanakları',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      for (final cue in readyHelp.sourceCues)
                        Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('• $cue')),
                    ],
                  ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                          '3 · Şimdi yardım almadan aktif olarak doğrula.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.30)),
                          ),
                          onPressed: _openRecall,
                          icon: const Icon(Icons.psychology_alt_outlined),
                          label: const Text('Hatırla'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppPalette.primaryDark,
                          ),
                          onPressed: _openExplainBack,
                          icon: const Icon(Icons.record_voice_over_outlined),
                          label: const Text('Kendi cümlelerinle anlat'),
                        ),
                      ),
                    ],
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
