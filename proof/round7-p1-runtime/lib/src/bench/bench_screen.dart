import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/proof_controller.dart';
import '../app/proof_screen.dart';
import 'bench_runner.dart';
import 'frame_stats.dart';

/// Runs T1–T11 on the live proof UI and shows / logs the raw report. The report is also
/// printed to the device log in chunks prefixed `R7P1_REPORT` so it can be captured with
/// `adb logcat` or the Xcode console.
class BenchScreen extends StatefulWidget {
  const BenchScreen({
    super.key,
    required this.controller,
    required this.assetBytes,
    this.soakCycles = 30,
    this.autoRun = false,
  });

  final ProofController controller;
  final int assetBytes;
  final int soakCycles;

  /// Starts T1–T11 immediately (used for unattended diagnostic runs, e.g. `?bench=1` on web).
  final bool autoRun;

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  String _status = 'Not started';
  String? _json;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoRun) WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _json = null;
    });
    final runner = ScenarioRunner(
      widget.controller,
      wait: (d) => Future<void>.delayed(d),
      collector: FrameCollector(),
      soakCycles: widget.soakCycles,
    );
    final report = await runner.runAll(
      assetBytes: widget.assetBytes,
      onProgress: (s) => setState(() => _status = 'Running $s'),
    );
    final json = ScenarioRunner.encode(report);
    // Compact, newline-free chunks survive logcat / browser console line handling.
    final compact = jsonEncode(report);
    for (var i = 0; i < compact.length; i += 900) {
      debugPrint('R7P1_REPORT ${i ~/ 900} ${compact.substring(i, (i + 900).clamp(0, compact.length))}');
    }
    debugPrint('R7P1_REPORT_END');
    if (!mounted) return;
    setState(() {
      _running = false;
      _status = 'Done: functional ${report['functional_result']}';
      _json = json;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('P1 benchmark (T1–T11)')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Build ${BuildIdentity.gitSha} · ${BuildIdentity.buildMode} · Flutter ${BuildIdentity.flutterVersion}\n'
              'Only a profile/release build on a physical device is decision-grade (R7-06). '
              'Record the exact device model with the report.',
            ),
          ),
          if (kDebugMode)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('DEBUG BUILD: timings are not performance evidence.', style: TextStyle(color: Colors.red)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const Key('run-benchmark'),
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running…' : 'Run T1–T11'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_status, key: const Key('bench-status')),
          ),
          if (_json != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: _json!)),
                child: const Text('Copy report JSON'),
              ),
            ),
          if (_json != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_json!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              ),
            ),
          if (_running)
            Expanded(
              child: IgnorePointer(child: ProofScreen(controller: widget.controller)),
            ),
        ],
      ),
    );
  }
}
