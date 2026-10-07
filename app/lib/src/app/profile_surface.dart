import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/account_overview_gateway.dart';
import 'app_runtime.dart';
import 'app_theme.dart';

const _configuredSupportEmail = String.fromEnvironment('SUPPORT_EMAIL');

class ProfileSurface extends StatefulWidget {
  const ProfileSurface({
    required this.runtime,
    this.onAccountDeleted,
    this.onSignOut,
    this.supportEmail = _configuredSupportEmail,
    this.clipboardWriter,
    super.key,
  });

  final AppRuntime runtime;
  final VoidCallback? onAccountDeleted;
  final Future<void> Function()? onSignOut;
  final String supportEmail;
  final Future<void> Function(String value)? clipboardWriter;

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

  String? get _supportEmail {
    final value = widget.supportEmail.trim();
    final at = value.indexOf('@');
    final dot = value.lastIndexOf('.');
    final hasWhitespace = value.contains(' ') || value.contains('\n') || value.contains('\t');
    if (value.isEmpty || value.length > 254 || hasWhitespace || at <= 0 || dot <= at + 1 || dot >= value.length - 1) {
      return null;
    }
    return value;
  }

  Future<void> _copySupportEmail() async {
    final email = _supportEmail;
    if (email == null) return;
    final writer = widget.clipboardWriter;
    if (writer == null) {
      await Clipboard.setData(ClipboardData(text: email));
    } else {
      await writer(email);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destek e-postası kopyalandı.')));
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
      key: const ValueKey('profile-surface'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      children: [
        Text(
          'HESAP VE AYARLAR',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppPalette.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        Text('Profil ve Ayarlar', style: theme.textTheme.headlineMedium),
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
              return _ProfilePanel(
                children: [
                  _ProfileTile(
                    icon: Icons.cloud_off_rounded,
                    title: 'Hesap bilgisi doğrulanamadı',
                    subtitle:
                        'Plan veya kullanım bilgisini tahmin etmiyoruz. Bağlantı geri geldiğinde yeniden deneyebilirsin.',
                    iconBackground: AppPalette.attentionSoft,
                    iconForeground: AppPalette.attention,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: OutlinedButton(onPressed: _retry, child: const Text('Yeniden dene')),
                  ),
                ],
              );
            }
            return _AccountOverviewCard(overview: overview);
          },
        ),
        const SizedBox(height: 26),
        const _ProfileSectionLabel('Hesap'),
        const SizedBox(height: 10),
        _ProfilePanel(
          children: [
            const _ProfileTile(
              icon: Icons.account_circle_outlined,
              title: 'Hesap oturumu',
              subtitle: 'Çıkış yapmak hesabını veya öğrenme verilerini silmez.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        const SizedBox(height: 24),
        const _ProfileSectionLabel('Tercihler'),
        const SizedBox(height: 10),
        _ProfilePanel(
          children: [
            const _ProfileTile(
              icon: Icons.language_rounded,
              title: 'Öğrenme dili',
              subtitle: 'Türkçe',
            ),
            const Divider(height: 1),
            const _ProfileTile(
              icon: Icons.record_voice_over_outlined,
              title: 'Dinleme sesi',
              subtitle: 'Cihazın Türkçe sesi',
              iconBackground: AppPalette.successSoft,
              iconForeground: AppPalette.success,
            ),
            const Divider(height: 1),
            _ProfileTile(
              icon: Icons.accessibility_new_rounded,
              title: 'Hareket tercihi',
              subtitle: MediaQuery.disableAnimationsOf(context)
                  ? 'Sistemde azaltılmış hareket açık'
                  : 'Sistemin hareket tercihi kullanılıyor',
              iconBackground: AppPalette.attentionSoft,
              iconForeground: AppPalette.attention,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _ProfileSectionLabel('Destek'),
        const SizedBox(height: 10),
        _ProfilePanel(
          children: [
            if (_supportEmail == null)
              const _ProfileTile(
                icon: Icons.support_agent_rounded,
                title: 'Destek',
                subtitle: 'Destek iletişim kanalı henüz yapılandırılmadı. Uygulama sahte bir adres göstermiyor.',
              )
            else ...[
              _ProfileTile(
                icon: Icons.support_agent_rounded,
                title: 'Destek',
                subtitle: _supportEmail!,
                iconBackground: AppPalette.successSoft,
                iconForeground: AppPalette.success,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: _copySupportEmail,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Destek e-postasını kopyala'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        const _ProfileSectionLabel('Verilerin'),
        const SizedBox(height: 10),
        _ProfilePanel(
          children: [
            const _ProfileTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik ve veriler',
              subtitle:
                  'Tek tek materyalleri Kütüphane’den silebilirsin. Hesap silme tüm hesap ve öğrenme verilerini kapsar.',
              iconBackground: Color(0xFFFDE7E5),
              iconForeground: AppPalette.destructive,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.destructive,
                  side: const BorderSide(color: Color(0xFFE7B8B4)),
                ),
                onPressed: _deleting ? null : _deleteAccount,
                icon: _deleting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(_deleting ? 'Siliniyor…' : 'Hesabımı ve verilerimi sil'),
              ),
            ),
          ],
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
    final active = overview.entitlementStatus == 'active';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.primaryDark,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primaryDark.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.workspace_premium_outlined, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(planLabel, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        active ? 'Plan etkin' : 'Plan durumu: ${overview.entitlementStatus}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.76)),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFB8F1E2).withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      active ? 'AKTİF' : 'DURUM',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: active ? const Color(0xFFB8F1E2) : Colors.white70,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              'KULLANIM',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFFAFC0FF),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 10),
            if (overview.usage.isEmpty)
              Text(
                'Bu hesap için sunucu kullanım kaydı henüz oluşmadı.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.78)),
              )
            else
              for (final entry in overview.usage.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _capabilityLabel(entry.capability),
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                      Text(
                        '${entry.consumed} işlem',
                        style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              'Dil: ${overview.locale}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
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

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.outline),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconBackground = AppPalette.primarySoft,
    this.iconForeground = AppPalette.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBackground;
  final Color iconForeground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, color: iconForeground, size: 20),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
