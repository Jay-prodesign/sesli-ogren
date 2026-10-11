import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import 'atelier_learning_surfaces.dart';

class FirstValueIntentSurface extends StatelessWidget {
  const FirstValueIntentSurface({
    required this.material,
    required this.sourceText,
    required this.sourceVersion,
    required this.onReadSource,
    required this.onQuickRecap,
    required this.onRecall,
    required this.onListen,
    required this.onFocus,
    super.key,
  });

  final MaterialRecord material;
  final String sourceText;
  final SourceVersionRecord sourceVersion;
  final VoidCallback onReadSource;
  final VoidCallback onQuickRecap;
  final VoidCallback onRecall;
  final VoidCallback onListen;
  final VoidCallback onFocus;

  bool get _recommendListenFirst => sourceText.trim().replaceAll(RegExp(r'\s+'), ' ').length > 1800;

  @override
  Widget build(BuildContext context) {
    final recommendedAction = _recommendListenFirst ? onListen : onReadSource;
    final recommendedLabel = _recommendListenFirst ? 'Sen öner · Dinleyerek başla' : 'Sen öner · Önce kaynağı oku';
    final recommendation = _recommendListenFirst
        ? 'Kaynak uzun. Henüz öğrenme kanıtın yok; nötr başlangıç olarak önce dinleyip genel yapıyı tanımayı öneriyoruz.'
        : 'Kaynak kısa. Henüz öğrenme kanıtın yok; nötr başlangıç olarak önce kaynağın tamamını görmeyi öneriyoruz.';

    return ColoredBox(
      key: const ValueKey('first-value-intent'),
      color: AtelierStyle.canvas,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(21, 14, 21, 30),
          children: [
            Text(
              material.mediaType == SourceMediaType.pdf ? 'PDF KAYNAĞI HAZIR' : 'KENDİ METNİN HAZIR',
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
                height: 1.14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            AtelierSourceTrustStrip(sourceVersion: sourceVersion),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
              decoration: BoxDecoration(
                color: AtelierStyle.mint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AtelierStyle.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Şimdi bununla ne yapmak istiyorsun?',
                    style: TextStyle(
                      color: AtelierStyle.ink,
                      fontSize: 19,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Bir yol seç. Bu kalıcı bir mod seçimi değil; aynı kaynağa dönüp istediğin zaman yol değiştirebilirsin.',
                    style: TextStyle(color: AtelierStyle.muted, fontSize: 12.5, height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const ValueKey('first-intent-listen'),
                    onPressed: onListen,
                    icon: const Icon(Icons.headphones_rounded),
                    label: const Text('Dinlemek istiyorum'),
                  ),
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    key: const ValueKey('first-intent-recap'),
                    onPressed: onQuickRecap,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Hızlıca anlamak istiyorum'),
                  ),
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    key: const ValueKey('first-intent-recall'),
                    onPressed: onRecall,
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('Bildiğimi kontrol etmek istiyorum'),
                  ),
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    key: const ValueKey('first-intent-focus'),
                    onPressed: onFocus,
                    icon: const Icon(Icons.center_focus_strong_rounded),
                    label: const Text('Birlikte çalışalım'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    key: const ValueKey('first-intent-recommend'),
                    onPressed: recommendedAction,
                    icon: const Icon(Icons.route_outlined),
                    label: Text(recommendedLabel),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation,
                    style: const TextStyle(color: AtelierStyle.muted, fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'İlk seçimin yalnız başlangıç yönünü belirler. Okuma, dinleme, aktif hatırlama ve odak çalışması aynı kaynakta birlikte kalır.',
              style: TextStyle(color: AtelierStyle.muted, fontSize: 12, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
