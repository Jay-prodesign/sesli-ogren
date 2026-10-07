import 'package:flutter/material.dart';

import '../account/account_overview_gateway.dart';
import 'app_runtime.dart';

class ProfileSurface extends StatefulWidget {
  const ProfileSurface({required this.runtime, super.key});

  final AppRuntime runtime;

  @override
  State<ProfileSurface> createState() => _ProfileSurfaceState();
}

class _ProfileSurfaceState extends State<ProfileSurface> {
  late Future<AccountOverview?> _overview;

  @override
  void initState() {
    super.initState();
    _overview = widget.runtime.accountOverview.load(learner: widget.runtime.learner);
  }

  void _retry() {
    setState(() {
      _overview = widget.runtime.accountOverview.load(learner: widget.runtime.learner);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text('Profil ve Ayarlar', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Hesap, plan ve doğrulanabilir kullanım bilgilerin.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        FutureBuilder<AccountOverview?>(
          future: _overview,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              );
            }
            final overview = snapshot.data;
            if (overview == null) {
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Hesap bilgisi doğrulanamadı',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Plan veya kullanım bilgisini tahmin etmiyoruz. Bağlantı geri geldiğinde yeniden deneyebilirsin.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _retry, child: const Text('Yeniden dene')),
                    ],
                  ),
                ),
              );
            }
            return _AccountOverviewCard(overview: overview);
          },
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          child: const Column(
            children: [
              ListTile(leading: Icon(Icons.language_rounded), title: Text('Öğrenme dili'), subtitle: Text('Türkçe')),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.record_voice_over_outlined),
                title: Text('Dinleme sesi'),
                subtitle: Text('Cihazın Türkçe sesi'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: const Icon(Icons.accessibility_new_rounded),
            title: const Text('Hareket tercihi'),
            subtitle: Text(
              MediaQuery.disableAnimationsOf(context)
                  ? 'Sistemde azaltılmış hareket açık'
                  : 'Sistemin hareket tercihi kullanılıyor',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          child: const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Gizlilik ve veriler'),
            subtitle: Text(
              'Materyallerini Kütüphane’den silebilirsin. Hesap silme ayrı güvenli akış olarak tamamlanacak.',
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountOverviewCard extends StatelessWidget {
  const _AccountOverviewCard({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planLabel = switch (overview.plan) {
      'free' => 'Ücretsiz plan',
      'premium' => 'Premium plan',
      'tester' => 'Test planı',
      _ => 'Plan doğrulanamadı',
    };

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(planLabel, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              overview.entitlementStatus == 'active' ? 'Plan etkin' : 'Plan durumu: ' + overview.entitlementStatus,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Text('Kullanım', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (overview.usage.isEmpty)
              const Text('Bu hesap için sunucu kullanım kaydı henüz oluşmadı.')
            else
              for (final entry in overview.usage.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(_capabilityLabel(entry.capability))),
                      Text(entry.consumed.toString() + ' işlem', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            const SizedBox(height: 12),
            Text(
              'Dil: ' + overview.locale,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  static String _capabilityLabel(String capability) => switch (capability) {
    'structured_generation' => 'AI üretimi',
    'grounded_explain' => 'Kaynağa dayalı açıklama',
    'explain_back' => 'Anlatım değerlendirme',
    _ => capability.replaceAll('_', ' '),
  };
}
