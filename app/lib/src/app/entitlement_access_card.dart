import 'package:flutter/material.dart';

import '../account/entitlement_access_gateway.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'living_study_desk_home.dart';

class EntitlementAccessCard extends StatelessWidget {
  const EntitlementAccessCard({
    required this.access,
    required this.onReturnToStudy,
    this.onRetry,
    super.key,
  });

  final EntitlementAccess access;
  final VoidCallback onReturnToStudy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final living = LivingDeskReviewScope.active(context);
    final isUpgradeBoundary = access.shouldShowUpgradeBoundary;
    final title = switch (access.kind) {
      EntitlementAccessKind.denied when access.reason == EntitlementAccessReason.quotaReached =>
        '${access.capability.displayLabel} sınırına ulaştın',
      EntitlementAccessKind.denied => '${access.capability.displayLabel} şu anda planında kullanılamıyor',
      EntitlementAccessKind.pending => 'Plan durumun doğrulanıyor',
      EntitlementAccessKind.unavailable => 'Plan bilgisi şu anda doğrulanamıyor',
      EntitlementAccessKind.allowed => '${access.capability.displayLabel} kullanılabilir',
    };
    final detail = switch (access.reason) {
      EntitlementAccessReason.quotaReached =>
        'Bu üretim hakkı için sunucunun doğruladığı dönem sınırı doldu. Daha önce oluşturduğun çalışmalar erişilebilir kalır.',
      EntitlementAccessReason.capabilityNotEntitled =>
        'Bu üretim türü mevcut doğrulanmış planında etkin değil. Kaydedilmiş çalışmaların etkilenmez.',
      EntitlementAccessReason.entitlementInactive || EntitlementAccessReason.entitlementMissing =>
        'Yeni üretim için etkin bir plan doğrulanamadı. Mevcut çalışma içeriğine dönmeye devam edebilirsin.',
      EntitlementAccessReason.purchasePending =>
        'Satın alma sonucu henüz sunucu tarafından doğrulanmadı. Doğrulama bitmeden erişim varmış gibi davranmıyoruz.',
      EntitlementAccessReason.restorePending =>
        'Mevcut satın alma bilgisi yeniden doğrulanıyor. Bu sırada kaydedilmiş çalışma içeriğini kullanabilirsin.',
      EntitlementAccessReason.reconciliationError =>
        'Plan kaydı şu anda güvenilir biçimde uzlaştırılamadı. Yanlış bir erişim veya ücret sonucu göstermiyoruz.',
      EntitlementAccessReason.verificationUnavailable || EntitlementAccessReason.unknown =>
        'Sunucu plan kararını doğrulayamadı. Yeni ücretli üretimi tahmin ederek başlatmıyoruz.',
      _ => 'Sunucu bu üretim için erişim durumunu doğruladı.',
    };
    final planLabel = switch (access.plan) {
      'free' => 'Ücretsiz plan',
      'premium' => 'Premium plan',
      'tester' => 'Test planı',
      _ => 'Plan doğrulanamadı',
    };
    final background = living ? AtelierStyle.paper : theme.colorScheme.surfaceContainerLow;
    final border = living ? AtelierStyle.line : theme.colorScheme.outlineVariant;
    final accent = living ? AtelierStyle.pulse : AppPalette.primary;

    return Container(
      key: const ValueKey('entitlement-access-boundary'),
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: living ? const [BoxShadow(color: Color(0x0B14224A), blurRadius: 18, offset: Offset(0, 7))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: living ? AtelierStyle.pulseSoft : AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    isUpgradeBoundary ? Icons.workspace_premium_outlined : Icons.sync_problem_outlined,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(detail, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: living ? AtelierStyle.canvas : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(planLabel, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                  if (access.limit > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${access.consumed} / ${access.limit} doğrulanmış kullanım',
                      key: const ValueKey('entitlement-access-usage'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUpgradeBoundary) ...[
            const SizedBox(height: 12),
            Text(
              'Daha yüksek bir plan üretim kapasitesini artırabilir. Doğrulanmış fiyat ve satın alma akışı henüz bağlı olmadığı için burada sahte bir teklif göstermiyoruz.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Kaydedilmiş özetler, okuma, Hatırla, quiz ve kart çalışmaları bu sınır yüzünden kilitlenmez.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const ValueKey('entitlement-access-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Plan durumunu yeniden kontrol et'),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('entitlement-access-return'),
            onPressed: onReturnToStudy,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Mevcut çalışmaya dön'),
          ),
        ],
      ),
    );
  }
}
