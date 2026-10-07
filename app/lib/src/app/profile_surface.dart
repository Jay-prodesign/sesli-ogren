import 'package:flutter/material.dart';

import '../account/account_overview_gateway.dart';
import 'app_runtime.dart';

class ProfileSurface extends StatefulWidget {
  const ProfileSurface({required this.runtime, this.onAccountDeleted, this.onSignOut, super.key});

  final AppRuntime runtime;
  final VoidCallback? onAccountDeleted;
  final Future<void> Function()? onSignOut;

  @override
  State<ProfileSurface> createState() => _ProfileSurfaceState();
}

class _ProfileSurfaceState extends State<ProfileSurface> {
  late Future<AccountOverview?> _overview;
  bool _deleting = false;
  bool _signingOut = false;

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

  Future<void> _signOut() async {
    final callback = widget.onSignOut;
    if (callback == null || _signingOut || _deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bu cihazda çıkış yap?'),
        content: const Text('Bu cihazdaki oturum kapanacak. Hesabın, materyallerin ve öğrenme verilerin silinmez.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Çıkış yap')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await callback();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum kapatılamadı. Hesabın açık kalıyor; tekrar deneyebilirsin.')),
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _deleteAccount() async {
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabı ve verileri sil?'),
        content: const Text(
          'Sunucudaki hesabın, öğrenme verilerin ve yüklediğin kaynak dosyaları kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Devam et')),
        ],
      ),
    );
    if (firstConfirmed != true || !mounted) return;

    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Son onay'),
        content: const Text('Bu işlem geri alınamaz. Hesabını ve verilerini kalıcı olarak silmek istiyor musun?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Kalıcı olarak sil')),
        ],
      ),
    );
    if (finalConfirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.runtime.deleteAccount();
      if (!mounted) return;
      final callback = widget.onAccountDeleted;
      if (callback != null) {
        callback();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hesap ve veriler silindi.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Hesap silinemedi. Verilerin korunuyor; tekrar deneyebilirsin.')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.account_circle_outlined),
                  title: Text('Hesap oturumu'),
                  subtitle: Text('Çıkış yapmak hesabını veya öğrenme verilerini silmez.'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: OutlinedButton.icon(
                    onPressed: widget.onSignOut == null || _signingOut || _deleting ? null : _signOut,
                    icon: _signingOut
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.logout_rounded),
                    label: Text(_signingOut ? 'Çıkış yapılıyor…' : 'Bu cihazda çıkış yap'),
                  ),
                ),
              ],
            ),
          ),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Gizlilik ve veriler'),
                  subtitle: Text(
                    'Tek tek materyalleri Kütüphane’den silebilirsin. Hesap silme tüm hesap ve öğrenme verilerini kapsar.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _deleteAccount,
                    icon: _deleting
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(_deleting ? 'Siliniyor…' : 'Hesabımı ve verilerimi sil'),
                  ),
                ),
              ],
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
              overview.entitlementStatus == 'active' ? 'Plan etkin' : 'Plan durumu: ${overview.entitlementStatus}',
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
                      Text('${entry.consumed} işlem', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            const SizedBox(height: 12),
            Text(
              'Dil: ${overview.locale}',
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
