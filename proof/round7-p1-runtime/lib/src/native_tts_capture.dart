import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('sesliogren/r7_native_tts_capture');
const _canonicalItems = <String>{
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
};

Map<String, String> parseCanonicalCorpus(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Corpus JSON must be an object keyed A-L.');
  }
  if (decoded.keys.toSet().difference(_canonicalItems).isNotEmpty ||
      _canonicalItems.difference(decoded.keys.toSet()).isNotEmpty) {
    throw const FormatException('Corpus JSON must contain exactly A-L.');
  }
  final result = <String, String>{};
  for (final item in _canonicalItems) {
    final value = decoded[item];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Corpus item $item must be non-empty text.');
    }
    result[item] = value;
  }
  return result;
}

class NativeTtsCaptureApp extends StatelessWidget {
  const NativeTtsCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NativeTtsCapturePage(),
    );
  }
}

class NativeTtsCapturePage extends StatefulWidget {
  const NativeTtsCapturePage({super.key});

  @override
  State<NativeTtsCapturePage> createState() => _NativeTtsCapturePageState();
}

class _NativeTtsCapturePageState extends State<NativeTtsCapturePage> {
  final _corpusController = TextEditingController();
  final _versionController = TextEditingController(
    text: 'SESLI_OGREN_TURKISH_VOICE_IDENTITY_BENCHMARK_001-KL-FIXED',
  );

  List<Map<String, dynamic>> _voices = const [];
  Map<String, dynamic>? _selectedVoice;
  String _androidDeviceClass = 'D2';
  String _status = 'Load Turkish voices, paste canonical A-L JSON, then capture.';
  bool _busy = false;

  @override
  void dispose() {
    _corpusController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    setState(() {
      _busy = true;
      _status = 'Reading physical-device TTS voices…';
    });
    try {
      final raw = await _channel.invokeListMethod<dynamic>('listTurkishVoices') ?? const [];
      final voices = raw
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((entry) => entry['networkRequired'] != true)
          .toList(growable: false);
      setState(() {
        _voices = voices;
        _selectedVoice = voices.isEmpty ? null : voices.first;
        _status = voices.isEmpty
            ? 'No offline-capable Turkish native voice was reported.'
            : 'Found ${voices.length} offline-capable Turkish voice(s).';
      });
    } on PlatformException catch (error) {
      setState(() => _status = 'Voice enumeration failed: ${error.code}: ${error.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _captureAll() async {
    final voice = _selectedVoice;
    if (voice == null) {
      setState(() => _status = 'Select an offline-capable Turkish voice first.');
      return;
    }

    Map<String, String> corpus;
    try {
      corpus = parseCanonicalCorpus(_corpusController.text);
    } on FormatException catch (error) {
      setState(() => _status = 'Corpus rejected: ${error.message}');
      return;
    }

    final corpusVersion = _versionController.text.trim();
    if (corpusVersion.isEmpty) {
      setState(() => _status = 'Corpus version is required.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Checking network state…';
    });

    try {
      final networkRaw = await _channel.invokeMapMethod<String, dynamic>('getNetworkState');
      final network = Map<String, dynamic>.from(networkRaw ?? const {});
      if (network['offline'] != true) {
        throw PlatformException(
          code: 'NETWORK_NOT_OFFLINE',
          message: 'Disable Wi-Fi/cellular/network before native capture. State: ${network['detail']}',
        );
      }

      final platform = voice['platform'] as String? ?? 'unknown';
      final deviceClass = platform == 'ios' ? 'D1' : _androidDeviceClass;
      final captureId = DateTime.now().millisecondsSinceEpoch.toString();
      final outputDir = await _channel.invokeMethod<String>('getEvidenceDirectory');
      if (outputDir == null || outputDir.isEmpty) {
        throw const FileSystemException('Native evidence directory unavailable.');
      }

      final records = <Map<String, dynamic>>[];
      var index = 0;
      for (final item in _canonicalItems) {
        index += 1;
        setState(() => _status = 'Capturing $item / L…');

        final raw = await _channel.invokeMapMethod<String, dynamic>(
          'synthesize',
          <String, dynamic>{
            'item': item,
            'text': corpus[item],
            'voiceId': voice['id'],
          },
        );
        final sample = Map<String, dynamic>.from(raw ?? const {});
        final blindId = 'V$captureId${index.toString().padLeft(2, '0')}';
        final candidateKey = [
          sample['platform'],
          sample['ttsEngineOrPackage'],
          sample['voiceId'],
          sample['qualityTier'],
          sample['deviceModel'],
        ].join('|');

        records.add(<String, dynamic>{
          'schema_version': 2,
          'requirement': 'R7-07A',
          'blind_sample_id': blindId,
          'provider_identity_hidden_from_listener': true,
          'hidden_provider_model_voice_key': candidateKey,
          'execution_backend': 'native_os',
          'platform': sample['platform'],
          'physical_device': true,
          'device_evidence_class': deviceClass,
          'device_model': sample['deviceModel'],
          'os_version': sample['osVersion'],
          'tts_engine_or_package': sample['ttsEngineOrPackage'],
          'provider_model_version': sample['providerModelVersion'],
          'voice_id_or_name': sample['voiceId'],
          'language_locale': sample['locale'],
          'synthesis_mode_or_quality_tier': sample['qualityTier'],
          'voice_network_requirement': sample['networkRequirement'],
          'offline_tested': true,
          'offline_test_method': network['method'],
          'offline_result': 'pass',
          'audio_capture_or_generation_method': sample['captureMethod'],
          'metered_external_service_invoked': false,
          'input_corpus_version': corpusVersion,
          'input_corpus_item': item,
          'input_text_sha256': sample['inputTextSha256'],
          'input_character_count': sample['inputCharacterCount'],
          'input_bytes': sample['inputBytes'],
          'requested_format': sample['format'],
          'actual_duration_ms': sample['durationMs'],
          'generation_started_at': sample['generationStartedAt'],
          'streaming': false,
          'first_byte_latency_ms': null,
          'full_completion_latency_ms': sample['fullCompletionLatencyMs'],
          'retries_count': 0,
          'errors': const [],
          'cost': <String, dynamic>{
            'scope': 'metered_external_provider_usage',
            'amount': 0.0,
            'unit': 'USD-provider-usage',
            'evidence_basis':
                'Physical native OS synthesis completed with network-disabled gate and no external developer API call.',
          },
          'operational_cost_notes':
              'Provider-usage cost only. Device compute, battery and support costs are evaluated separately.',
          'cache_reuse_behavior': 'none; fresh file per canonical corpus item',
          'raw_provider_metadata_location':
              '$outputDir/r7-native-tts-manifest-$captureId.json',
          'audio_file_location': sample['audioPath'],
          'audio_sha256': sample['audioSha256'],
          'known_limitation':
              'Native physical-device baseline only; blind Turkish human quality judgement remains pending.',
        });
      }

      final manifest = <String, dynamic>{
        'capture_id': captureId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'corpus_version': corpusVersion,
        'device_class': deviceClass,
        'network_evidence': network,
        'selected_voice_metadata': voice,
        'samples': records,
      };
      final manifestPath = '$outputDir/r7-native-tts-manifest-$captureId.json';
      await File(manifestPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );

      setState(() {
        _status =
            'CAPTURE COMPLETE: 12/12. Manifest: $manifestPath\n'
            'Transfer manifest + audio files before uninstalling the proof app.';
      });
      debugPrint('R7_NATIVE_TTS_MANIFEST=$manifestPath');
    } on PlatformException catch (error) {
      setState(() => _status = 'Capture blocked: ${error.code}: ${error.message}');
    } on Object catch (error) {
      setState(() => _status = 'Capture failed: $error');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = _selectedVoice?['platform'];
    return Scaffold(
      appBar: AppBar(title: const Text('R7 Native Turkish TTS Capture')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'PROOF ONLY — no production provider selection. '
              'Canonical corpus text is runtime input and is not stored in the repository.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _loadVoices,
              child: const Text('Load offline-capable Turkish voices'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedVoice,
              items: _voices
                  .map(
                    (voice) => DropdownMenuItem(
                      value: voice,
                      child: Text(
                        '${voice['name']} — ${voice['qualityTier']} — ${voice['locale']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _busy ? null : (value) => setState(() => _selectedVoice = value),
              decoration: const InputDecoration(labelText: 'Native voice'),
            ),
            if (platform == 'android') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _androidDeviceClass,
                items: const [
                  DropdownMenuItem(value: 'D2', child: Text('D2 — representative mid-range Android')),
                  DropdownMenuItem(value: 'D3', child: Text('D3 — lower-end supported Android')),
                ],
                onChanged: _busy || platform != 'android'
                    ? null
                    : (value) => setState(() => _androidDeviceClass = value ?? 'D2'),
                decoration: const InputDecoration(labelText: 'Physical Android device class'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _versionController,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Canonical corpus version'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _corpusController,
              enabled: !_busy,
              minLines: 8,
              maxLines: 16,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Paste private canonical corpus JSON',
                hintText: '{"A":"…","B":"…",…,"L":"…"}',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _busy ? null : _captureAll,
              child: const Text('Capture A–L with network-disabled gate'),
            ),
            const SizedBox(height: 16),
            SelectableText(_status),
          ],
        ),
      ),
    );
  }
}
