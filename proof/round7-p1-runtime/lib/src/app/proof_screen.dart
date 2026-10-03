import 'package:flutter/material.dart';

import '../flow/flow_engine.dart';
import '../render/companion_renderer.dart';
import '../render/views.dart';
import '../render/world_painter.dart';
import '../scene/scene_schema.dart';
import 'proof_controller.dart';

/// Shared paint counters so tests and the benchmark can compare tier cost.
final worldStats = PaintStats();
final companionStats = PaintStats();

class ProofScreen extends StatelessWidget {
  const ProofScreen({
    super.key,
    required this.controller,
    this.onOpenNativeSpeechQa,
    this.onOpenBenchmark,
    this.companionRenderer,
  });

  final ProofController controller;
  final VoidCallback? onOpenNativeSpeechQa;
  final VoidCallback? onOpenBenchmark;

  /// Optional test/host override. When null the selected Founder companion
  /// (D/Knot or E/Tilt) is resolved from the controller.
  final CompanionRenderer? companionRenderer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final e = controller.engine;
        final reduced = controller.reducedMotion || MediaQuery.disableAnimationsOf(context);
        final activeCompanionRenderer = companionRenderer ?? _rendererFor(controller.companionIdentity);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Round 7 · P1 runtime proof'),
            actions: [
              IconButton(
                tooltip: 'Proof conditions',
                icon: const Icon(Icons.tune),
                onPressed: () => _conditions(context),
              ),
              if (onOpenNativeSpeechQa != null)
                IconButton(
                  tooltip: 'Native Speech QA',
                  icon: const Icon(Icons.record_voice_over),
                  onPressed: onOpenNativeSpeechQa,
                ),
              if (onOpenBenchmark != null)
                IconButton(tooltip: 'Benchmark', icon: const Icon(Icons.speed), onPressed: onOpenBenchmark),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                // One scrollable page: large text or small screens never push actions off-screen.
                final compactLandscape = box.maxWidth > box.maxHeight && box.maxHeight < 600;
                final worldHeight = compactLandscape
                    ? (box.maxHeight * 0.34).clamp(120.0, 150.0)
                    : (box.maxHeight * 0.4).clamp(200.0, 360.0);
                return SingleChildScrollView(
                  key: const Key('proof-scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ProofBanner(),
                      _SourceBar(controller: controller),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          height: worldHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: WorldView(scene: e.scene, reducedMotion: reduced, stats: worldStats),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: _FlowPanel(
                          controller: controller,
                          reducedMotion: reduced,
                          companionRenderer: activeCompanionRenderer,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  static CompanionRenderer _rendererFor(CompanionIdentity identity) {
    return switch (identity) {
      CompanionIdentity.knot => const RasterCompanionRenderer.knot(),
      CompanionIdentity.tilt => const RasterCompanionRenderer.tilt(),
    };
  }

  void _conditions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Fixture (T7)')),
            RadioGroup<int>(
              groupValue: controller.fixtureIndex,
              onChanged: (v) => controller.selectFixture(v!),
              child: Column(
                children: [
                  for (var i = 0; i < controller.fixtures.length; i++)
                    RadioListTile<int>(value: i, title: Text(controller.fixtures[i].domainLabel)),
                ],
              ),
            ),
            const ListTile(title: Text('Companion identity')),
            RadioGroup<CompanionIdentity>(
              groupValue: controller.companionIdentity,
              onChanged: (v) => controller.setCompanionIdentity(v!),
              child: const Column(
                children: [
                  RadioListTile<CompanionIdentity>(value: CompanionIdentity.knot, title: Text('D · Knot')),
                  RadioListTile<CompanionIdentity>(value: CompanionIdentity.tilt, title: Text('E · Tilt')),
                ],
              ),
            ),
            const ListTile(title: Text('Render tier (T8)')),
            RadioGroup<FallbackLevel>(
              groupValue: controller.tier,
              onChanged: (v) => controller.setTier(v!),
              child: Column(
                children: [
                  for (final t in FallbackLevel.values)
                    RadioListTile<FallbackLevel>(value: t, title: Text(wireName(t))),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Reduced motion (T9)'),
              value: controller.reducedMotion,
              onChanged: controller.setReducedMotion,
            ),
            SwitchListTile(
              title: const Text('Audio available (T10)'),
              value: controller.audioAvailable,
              onChanged: controller.setAudioAvailable,
            ),
            SwitchListTile(
              title: const Text('Simulate Companion asset failure'),
              value: controller.companionAssetFailed,
              onChanged: controller.setCompanionAssetFailed,
            ),
            SwitchListTile(
              title: const Text('Simulate world asset failure'),
              value: controller.worldAssetFailed,
              onChanged: controller.setWorldAssetFailed,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofBanner extends StatelessWidget {
  const _ProofBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF4D6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Text(
        'Proof only, not production UI. Evidence classes are simulated fixture responses; the '
        'Companion uses the Founder-selected D/Knot or E/Tilt raster identity; interactive mode uses device TTS.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}

class _SourceBar extends StatelessWidget {
  const _SourceBar({required this.controller});

  final ProofController controller;

  @override
  Widget build(BuildContext context) {
    final f = controller.fixture;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(child: Text('${f.domainLabel}\n${f.objective}', style: Theme.of(context).textTheme.bodyMedium)),
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source ${f.source.id} · v${f.source.version}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(f.source.text),
                    const SizedBox(height: 8),
                    Text('${f.source.authority}. ${f.source.provenance}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            child: const Text('Source'),
          ),
        ],
      ),
    );
  }
}

class _FlowPanel extends StatelessWidget {
  const _FlowPanel({required this.controller, required this.reducedMotion, required this.companionRenderer});

  final ProofController controller;
  final bool reducedMotion;
  final CompanionRenderer companionRenderer;

  @override
  Widget build(BuildContext context) {
    final e = controller.engine;
    final theme = Theme.of(context);
    final b = e.branch;
    final viewport = MediaQuery.sizeOf(context);
    final compactLandscape = viewport.width > viewport.height && viewport.height < 600;
    final companionExtent = compactLandscape ? 104.0 : 124.0;
    final companionColumnWidth = companionExtent + 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: companionColumnWidth,
              child: CompanionView(
                state: controller.companionState,
                tone: e.companionTone,
                tier: controller.tier,
                reducedMotion: reducedMotion,
                assetFailed: controller.companionAssetFailed,
                stats: companionStats,
                visualExtent: companionExtent,
                renderer: companionRenderer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_stepTitle(e.step), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(e.spokenText, key: const Key('transcript'), style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  _voiceStatus(context),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (e.step == FlowStep.feedback && b != null) ...[
          if (b.hint != null && e.evidence == EvidenceState.partial) Text('Hint: ${b.hint}'),
          Text('Next: ${b.nextAction}', key: const Key('next-action'), style: theme.textTheme.titleSmall),
          Text('reason ${e.reasonCode}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
        if (e.step == FlowStep.repairCheck && b?.hint != null && e.evidence == EvidenceState.partial)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Hint: ${b!.hint}')),
        ..._actions(context),
      ],
    );
  }

  Widget _voiceStatus(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (!controller.audioAvailable) {
      return Text('Audio unavailable: text shown instead', key: const Key('audio-status'), style: style);
    }
    final voiceLabel = controller.usingRealSpeech ? 'Device voice' : 'Voice (simulated)';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$voiceLabel ${controller.speaking ? 'speaking' : 'idle'}', style: style),
        if (controller.speaking)
          TextButton(onPressed: controller.stopSpeaking, child: const Text('Stop'))
        else if (const {FlowStep.orient, FlowStep.teach, FlowStep.repairTeach}.contains(controller.engine.step))
          TextButton(onPressed: controller.replaySpeech, child: const Text('Replay')),
      ],
    );
  }

  static String _stepTitle(FlowStep s) => switch (s) {
    FlowStep.context => 'S1 · Continue where it matters',
    FlowStep.orient => 'S2 · Orientation',
    FlowStep.teach => 'S3 · Teach / listen',
    FlowStep.challenge => 'S4 · Active quest',
    FlowStep.evaluating => 'Checking',
    FlowStep.feedback => 'S5 · Evidence · S6 · Next action',
    FlowStep.repairTeach => 'Repair · corrective teaching',
    FlowStep.repairCheck => 'Repair · smaller check',
    FlowStep.complete => 'S7 · Session milestone',
  };

  List<Widget> _actions(BuildContext context) {
    final e = controller.engine;
    Widget primary(String label, VoidCallback onTap, {Key? key}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FilledButton(key: key, onPressed: onTap, child: Text(label)),
    );
    Widget secondary(String label, VoidCallback onTap, {Key? key}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: OutlinedButton(
        key: key,
        onPressed: onTap,
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
    switch (e.step) {
      case FlowStep.context:
        return [primary('Continue', controller.orient, key: const Key('act-primary'))];
      case FlowStep.orient || FlowStep.teach || FlowStep.repairTeach:
        return [primary('Continue', controller.advance, key: const Key('act-primary'))];
      case FlowStep.challenge:
        return [
          Text(
            'Simulated learner responses (deterministic fixture evidence):',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final s in [EvidenceState.strong, EvidenceState.partial, EvidenceState.misconception])
            secondary('"${e.fixture.responses[s]}"', () => controller.submit(s), key: Key('respond-${wireName(s)}')),
          secondary('Input interrupted', controller.interrupt, key: const Key('respond-UNKNOWN')),
        ];
      case FlowStep.evaluating:
        return const [Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator())];
      case FlowStep.feedback:
        return [primary('Continue', controller.follow, key: const Key('act-primary'))];
      case FlowStep.repairCheck:
        final answer = e.branch?.repairAnswer ?? 'Answer';
        return [
          secondary('"$answer"', () => controller.submitRepair(correct: true), key: const Key('repair-correct')),
          secondary(
            'A different answer',
            () => controller.submitRepair(correct: false),
            key: const Key('repair-incorrect'),
          ),
          secondary('Input interrupted', controller.interrupt, key: const Key('repair-interrupt')),
        ];
      case FlowStep.complete:
        return [
          Text('Session milestone, not permanent mastery. Next: ${e.fixture.nextContinuation}'),
          primary('Restart this fixture', controller.restart, key: const Key('act-primary')),
        ];
    }
  }
}
