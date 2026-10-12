import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/account_overview_gateway.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'living_study_desk_home.dart';

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
  AccountOverview? _resolvedOverview;
  bool _deleting = false;
  bool _signingOut = false;
  bool _remoteDeletionConfirmed = false;

  @override
  void initState() {
    super.initState();
    _overview = _loadOverview();
  }

  Future<AccountOverview?> _loadOverview() async {
    final overview = await widget.runtime.accountOverview.load(learner: widget.runtime.learner);
    if (mounted) setState(() => _resolvedOverview = overview);
    return overview;
  }

  void _retry() {
    setState(() {
      _resolvedOverview = null;
      _overview = _loadOverview();
    });
  }

  bool get _deletionAlreadyRequested =>
      _resolvedOverview?.accountStatus == 'deletion_requested' || _resolvedOverview?.accountStatus == 'deleted';

  String get _deletionActionLabel {
    if (_remoteDeletionConfirmed) {
      return _deleting ? 'Yerel veriler temizleniyor…' : 'Yerel veriyi temizlemeyi tekrar dene';
    }
    return switch (_resolvedOverview?.accountStatus) {
      'deletion_requested' => 'Silme isteği zaten bekliyor',
      'deleted' => 'Hesap silinmiş görünüyor',
      _ when _deleting => 'Siliniyor…',
      _ => 'Hesabımı ve verilerimi sil',
    };
  }

  Future<void> _signOut() async {
    final callback = widget.onSignOut;
    if (callback == null || _signingOut || _deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bu cihazda çıkış yap?'),
        content: const Text('Bu cihazdaki oturum kapanacak. Misafir olarak devam ediyorsan, hesabına bağlanmamış materyal ve ilerlemene yeniden erişemeyebilirsin. Çıkış yapmadan önce bunu dikkate al.'),
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
    try {
      final writer = widget.clipboardWriter;
      if (writer == null) {
        await Clipboard.setData(ClipboardData(text: email));
      } else {
        await writer(email);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destek e-postası kopyalandı.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destek e-postası kopyalanamadı. Adresi seçip tekrar deneyebilirsin.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    if (_deleting || _deletionAlreadyRequested) return;
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
    } on AccountDeletionLocalCleanupException {
      if (!mounted) return;
      setState(() => _remoteDeletionConfirmed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hesap sunucuda silindi ancak bu cihazdaki yerel veriler henüz temizlenemedi. '
            'Sunucuya yeni silme isteği göndermeden yerel temizliği tekrar deneyebilirsin.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Hesap silinemedi. Verilerin korunuyor; tekrar deneyebilirsin.')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _retryLocalCleanup() async {
    if (_deleting || !_remoteDeletionConfirmed) return;
    setState(() => _deleting = true);
    try {
      await widget.runtime.retryDeletedAccountLocalCleanup();
      if (!mounted) return;
      final callback = widget.onAccountDeleted;
      if (callback != null) {
        callback();
      } else {
        setState(() => _remoteDeletionConfirmed = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bu cihazdaki yerel veriler temizlendi.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yerel veriler henüz temizlenemedi. Sunucuya yeni silme isteği gönderilmedi; yalnız cihaz temizliği tekrar denenebilir.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final living = LivingDeskReviewScope.active(context);
    final accent = living ? AtelierStyle.teal : AppPalette.primary;
    final ink = living ? AtelierStyle.ink : theme.colorScheme.onSurface;
    final muted = living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant;
    return ListView(
      key: const ValueKey('profile-surface'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      children: [
        Text(
          'HESAP VE AYARLAR',
          style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const SizedBox(height: 7),
        Text(
          'Profil ve Ayarlar',
          style: theme.textTheme.headlineMedium?.copyWith(color: ink, fontWeight: living ? FontWeight.w900 : null),
        ),
        const SizedBox(height: 6),
        Text(
          'Hesap, plan ve doğrulanabilir kullanım bilgilerin.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 22),
        FutureBuilder<AccountOverview?>(
          future: _overview,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _AccountOverviewLoadingCard();
            }
            final overview = snapshot.data;
            if (overview == null) {
              return _ProfilePanel(
                children: [
                  _ProfileTile(
                    icon: Icons.cloud_off_rounded,
                    title: 'Hesap bilgisi doğrulanamadı',
                    subtitle: 'Plan veya kullanım bilgisini tahmin etmiyoruz. Bağlantı geri geldiğinde yeniden deneyebilirsin.',
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
            const _ProfileTile(icon: Icons.language_rounded, title: 'Öğrenme dili', subtitle: 'Türkçe'),
            const Divider(height: 1),
            const _ProfileTile(
              icon: Icons.record_voice_over_outlined,
              title: 'Dinleme sesi',
              subtitle: 'Türkçe ses · cihaz desteği dinlerken doğrulanır',
              iconBackground: AppPalette.signalSoft,
              iconForeground: AppPalette.signal,
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
                iconBackground: AppPalette.signalSoft,
                iconForeground: AppPalette.signal,
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
            _ProfileTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik ve veriler',
              subtitle: _remoteDeletionConfirmed
                  ? 'Sunucu hesabı silindi. Bu cihazdaki yerel öğrenme verilerinin temizliği tamamlanmayı bekliyor.'
                  : switch (_resolvedOverview?.accountStatus) {
                      'deletion_requested' => 'Hesap silme isteği sunucuda bekliyor. Aynı silme isteğini tekrar göndermiyoruz; süreç tamamlanana kadar bu durum korunur.',
                      'deleted' =>
                        'Sunucu hesabı silinmiş olarak bildiriyor. Bu ekrandan yeni bir silme isteği gönderilmiyor.',
                      _ => 'Tek tek materyalleri Kütüphane’den silebilirsin. Hesap silme tüm hesap ve öğrenme verilerini kapsar.',
                    },
              iconBackground: const Color(0xFFFDE7E5),
              iconForeground: AppPalette.destructive,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.destructive,
                  side: const BorderSide(color: Color(0xFFE7B8B4)),
                ),
                onPressed: _deleting || (_deletionAlreadyRequested && !_remoteDeletionConfirmed)
                    ? null
                    : (_remoteDeletionConfirmed ? _retryLocalCleanup : _deleteAccount),
                icon: _deleting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        _remoteDeletionConfirmed
                            ? Icons.delete_sweep_outlined
                            : _deletionAlreadyRequested
                            ? Icons.hourglass_top_rounded
                            : Icons.delete_forever_outlined,
                      ),
                label: Text(_deletionActionLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountOverviewLoadingCard extends StatelessWidget {
  const _AccountOverviewLoadingCard();

  @override
  Widget build(BuildContext context) {
    final living = LivingDeskReviewScope.active(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: living ? AtelierStyle.paper : AppPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: living ? const Border(left: BorderSide(color: AtelierStyle.pulse, width: 4)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(13)),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.person_search_outlined, color: AppPalette.primary),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hesap alanın hazırlanıyor',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: AppPalette.ink, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  'Plan ve doğrulanmış kullanım bilgilerin getiriliyor.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppPalette.inkMuted, height: 1.4),
                ),
                const SizedBox(height: 14),
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: AppPalette.primary,
                  backgroundColor: AppPalette.primarySoft,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountOverviewCard extends StatelessWidget {
  const _AccountOverviewCard({required this.overview});

  final AccountOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final living = LivingDeskReviewScope.active(context);
    final knownPlan = switch (overview.plan) {
      'free' || 'premium' || 'tester' => true,
      _ => false,
    };
    final planLabel = switch (overview.plan) {
      'free' => 'Ücretsiz plan',
      'premium' => 'Premium plan',
      'tester' => 'Test planı',
      _ => 'Plan doğrulanamadı',
    };
    final accountLabel = switch (overview.accountStatus) {
      'active' => null,
      'deletion_requested' => 'Hesap silme isteği bekliyor',
      'deleted' => 'Hesap silindi',
      _ => 'Hesap durumu doğrulanamadı',
    };
    final entitlementLabel = switch (overview.entitlementStatus) {
      'active' => knownPlan ? 'Plan etkin' : 'Plan veya erişim durumu doğrulanamadı',
      'expired' => 'Plan süresi doldu',
      'revoked' => 'Plan erişimi kaldırıldı',
      _ => 'Plan durumu doğrulanamadı',
    };
    final active = accountLabel == null && knownPlan && overview.entitlementStatus == 'active';
    final statusLabel = accountLabel ?? entitlementLabel;
    final badgeLabel = active
        ? 'AKTİF'
        : switch (overview.entitlementStatus) {
            'expired' when accountLabel == null => 'SÜRESİ DOLDU',
            'revoked' when accountLabel == null => 'KAPALI',
            _ => 'DOĞRULANAMADI',
          };

    final usageByCapability = <String, AccountUsageEntry>{};
    final unknownUsage = <AccountUsageEntry>[];
    for (final entry in overview.usage) {
      final capability = _canonicalCapability(entry.capability);
      if (capability == null) {
        unknownUsage.add(entry);
      } else {
        usageByCapability[capability] = entry;
      }
    }
    final quotaCapabilities = <String>['summary', 'explain', 'focus', 'explain_back']
        .where(
          (capability) =>
              overview.dailyLimitForCapability(capability) != null || usageByCapability.containsKey(capability),
        )
        .toList(growable: false);
    final hasVerifiedLimits = overview.dailyLimits.isNotEmpty;
    final hasUsageOrLimits = quotaCapabilities.isNotEmpty || unknownUsage.isNotEmpty;

    Widget usageRow(String label, String value, {bool strongValue = false}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final labelWidget = Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.ink));
          final valueWidget = Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppPalette.primaryDark,
              fontWeight: strongValue ? FontWeight.w800 : null,
            ),
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 3), valueWidget],
            );
          }
          return Row(
            children: [
              Expanded(child: labelWidget),
              const SizedBox(width: 10),
              valueWidget,
            ],
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        color: living ? AtelierStyle.paper : AppPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: living ? const Border(left: BorderSide(color: AtelierStyle.pulse, width: 4)) : null,
        boxShadow: living ? const [BoxShadow(color: Color(0x0A14224A), blurRadius: 18, offset: Offset(0, 7))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(16) >= 22;
              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: AppPalette.primarySoft, borderRadius: BorderRadius.circular(13)),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.workspace_premium_outlined, color: AppPalette.primary),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planLabel,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppPalette.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(statusLabel, style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.inkMuted)),
                      ],
                    ),
                  ),
                ],
              );
              final badge = DecoratedBox(
                decoration: BoxDecoration(
                  color: active ? AppPalette.successSoft : AppPalette.attentionSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    badgeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: active ? AppPalette.success : AppPalette.attention,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
              if (stack) {
                return Column(
                  key: const ValueKey('profile-account-header-stacked'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 12), badge],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 10),
                  badge,
                ],
              );
            },
          ),
          const SizedBox(height: 17),
          const Divider(color: AppPalette.outline),
          const SizedBox(height: 14),
          Text(
            'KULLANIM',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppPalette.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 10),
          if (!hasUsageOrLimits)
            Text(
              'Bu hesap için doğrulanmış günlük limit veya kullanım kaydı henüz oluşmadı.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.inkMuted),
            )
          else ...[
            for (final capability in quotaCapabilities)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: usageRow(
                  _capabilityLabel(capability),
                  _usageAndLimitLabel(
                    usageByCapability[capability]?.consumed ?? 0,
                    overview.dailyLimitForCapability(capability),
                  ),
                  strongValue: true,
                ),
              ),
            for (final entry in unknownUsage.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: usageRow(
                  _capabilityLabel(entry.capability),
                  entry.consumed < 0 ? 'Doğrulanamadı' : '${entry.consumed} işlem',
                ),
              ),
            const SizedBox(height: 2),
            Text(
              hasVerifiedLimits
                  ? 'Günlük sınırlar sunucu planından gelir; burada tamamlanan kullanım gösterilir.'
                  : 'Bu sayılar sunucunun kaydettiği kullanımdır; kalan hak veya limit tahmini değildir.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.inkMuted, height: 1.35),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Dil: ${_localeLabel(overview.locale)}',
            style: theme.textTheme.bodySmall?.copyWith(color: AppPalette.inkMuted),
          ),
        ],
      ),
    );
  }

  static String? _canonicalCapability(String capability) => switch (capability) {
    'summary' => 'summary',
    'explain' || 'grounded_explain' => 'explain',
    'focus' => 'focus',
    'explain_back' => 'explain_back',
    _ => null,
  };

  static String _usageAndLimitLabel(int consumed, int? limit) {
    if (consumed < 0) return limit == null ? 'Doğrulanamadı' : 'Doğrulanamadı / $limit';
    return limit == null ? '$consumed işlem' : '$consumed / $limit bugün';
  }

  static String _capabilityLabel(String capability) => switch (capability) {
    'summary' => 'Quick Recap',
    'explain' => 'Kaynağa dayalı açıklama',
    'structured_generation' => 'AI üretimi',
    'grounded_explain' => 'Kaynağa dayalı açıklama',
    'explain_back' => 'Anlatım değerlendirme',
    'focus' => 'Odak AI yardımı',
    _ => 'Diğer kullanım',
  };

  static String _localeLabel(String locale) => switch (locale) {
    'tr' || 'tr-TR' => 'Türkçe',
    'en' || 'en-US' || 'en-GB' => 'English',
    _ => 'Doğrulanamadı',
  };
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final living = LivingDeskReviewScope.active(context);
    return Text(
      text,
      style: living
          ? Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AtelierStyle.pulse, fontWeight: FontWeight.w900, letterSpacing: 0.7)
          : Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final living = LivingDeskReviewScope.active(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: living ? AppPalette.surfaceMuted : AppPalette.surface,
        borderRadius: BorderRadius.circular(18),
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
    final living = LivingDeskReviewScope.active(context);
    final resolvedBackground = iconBackground;
    final resolvedForeground = iconForeground;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: resolvedBackground, borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, color: resolvedForeground, size: 20),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: living ? AtelierStyle.ink : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant,
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
