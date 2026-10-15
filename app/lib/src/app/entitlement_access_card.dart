import 'package:flutter/material.dart';

import '../account/entitlement_access_gateway.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'living_study_desk_home.dart';

class EntitlementAccessCard extends StatelessWidget {
  const EntitlementAccessCard({required this.decision, required this.onRecheck, required this.onBack, super.key});

  final CapabilityAccessDecision decision;
  final VoidCallback onRecheck;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final living = LivingDeskReviewScope.active(context);
    final theme = Theme.of(context);
    final background = living ? AtelierStyle.paper : theme.colorScheme.surfaceContainerLow;
    final line = living ? AtelierStyle.line : theme.colorScheme.outlineVariant;
    final ink = living ? AtelierStyle.ink : theme.colorScheme.onSurface;
    final muted = living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant;
    final accent = living ? AtelierStyle.pulse : theme.colorScheme.primary;
    final used = decision.authoritativeUsed;
    final limit = decision.limit;

    final title = switch (decision.reason) {
      CapabilityAccessReason.quotaReached => 'Bugünkü üretim sınırına ulaştın',
      CapabilityAccessReason.capabilityNotEntitled => 'Bu üretim özelliği mevcut planında açık değil',
      CapabilityAccessReason.entitlementInactive ||
      CapabilityAccessReason.entitlementMissing => 'Plan erişimi şu anda doğrulanmıyor',
      _ => 'Erişim durumu doğrulanamadı',
    };

    final detail = switch (decision.reason) {
      CapabilityAccessReason.quotaReached =>
        '${decision.capability.label} için sunucunun doğruladığı günlük kullanım sınırı doldu.',
      CapabilityAccessReason.capabilityNotEntitled =>
        '${decision.capability.label} için mevcut planında yeni üretim hakkı bulunmuyor.',
      CapabilityAccessReason.entitlementInactive =>
        'Sunucu plan durumunu ${_statusLabel(decision.entitlementStatus)} olarak doğruladı. Yeni ücretli üretim başlatmıyoruz.',
      CapabilityAccessReason.entitlementMissing =>
        'Bu hesap için sunucuda geçerli bir erişim kaydı bulunamadı. Client tarafında erişim uydurmuyoruz.',
      _ => 'Sunucu erişim kararını doğrulayamadı.',
    };

    return Container(
      key: const ValueKey('entitlement-access-card'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_clock_outlined, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(detail, style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.4)),
          if (limit != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const ValueKey('entitlement-usage-row'),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: living ? AtelierStyle.canvas : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_planLabel(decision.plan)} · ${decision.capability.label}',
                      style: theme.textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$used / $limit',
                    key: const ValueKey('entitlement-usage-value'),
                    style: theme.textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Daha yüksek plan kapasitesi yalnız yeni üretim hakkını değiştirir. Kaynakların, mevcut öğrenme kanıtların ve daha önce oluşturduğun içerikler açık kalır.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 320 || MediaQuery.textScalerOf(context).scale(1) > 1.25;
              final recheck = FilledButton.icon(
                key: const ValueKey('entitlement-recheck'),
                onPressed: onRecheck,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Erişimi yeniden kontrol et'),
              );
              final back = OutlinedButton.icon(
                key: const ValueKey('entitlement-safe-back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Çalışmaya dön'),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [recheck, const SizedBox(height: 8), back],
                );
              }
              return Row(
                children: [
                  Expanded(child: recheck),
                  const SizedBox(width: 8),
                  Expanded(child: back),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _planLabel(String? value) => switch (value) {
    'free' => 'Ücretsiz plan',
    'premium' => 'Premium plan',
    'tester' => 'Test planı',
    _ => 'Plan doğrulanamadı',
  };

  static String _statusLabel(String? value) => switch (value) {
    'active' => 'etkin',
    'expired' => 'süresi dolmuş',
    'revoked' => 'erişimi kaldırılmış',
    _ => 'doğrulanamayan',
  };
}
