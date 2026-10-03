import 'package:flutter/material.dart';

import '../bench/bench_screen.dart';
import '../scene/fixture.dart';
import '../speech/device_speech_output.dart';
import 'proof_controller.dart';
import 'proof_screen.dart';

class ProofApp extends StatefulWidget {
  const ProofApp({super.key, required this.fixtures, required this.assetBytes});

  final List<ProofFixture> fixtures;
  final int assetBytes;

  @override
  State<ProofApp> createState() => _ProofAppState();
}

class _ProofAppState extends State<ProofApp> {
  /// Unattended diagnostic mode: `?bench=1[&cycles=N]` in the launch URL (web only in practice).
  static final _query = Uri.base.queryParameters;
  static final bool _autoBench = _query['bench'] == '1';
  static final int _cycles = int.tryParse(_query['cycles'] ?? '') ?? 30;

  late final SpeechOutput? _speechOutput = _autoBench ? null : DeviceSpeechOutput(locale: 'en-US');
  late final ProofController _controller = ProofController(widget.fixtures, speechOutput: _speechOutput);
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R7 P1 runtime proof',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F3A5F), useMaterial3: true),
      home: _autoBench
          ? BenchScreen(controller: _controller, assetBytes: widget.assetBytes, soakCycles: _cycles, autoRun: true)
          : ProofScreen(
              controller: _controller,
              onOpenBenchmark: () => _navigator.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => BenchScreen(controller: _controller, assetBytes: widget.assetBytes),
                ),
              ),
            ),
    );
  }
}
