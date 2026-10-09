import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'app_theme.dart';

class ProgressItem {
  const ProgressItem({required this.material, required this.continuation});
  final MaterialRecord material;
  final LearningContinuation? continuation;
}

class ProgressSurface extends StatelessWidget {
  const ProgressSurface({required this.items, required this.onOpenMaterial, super.key});
  final List<ProgressItem> items;
  final ValueChanged<MaterialId> onOpenMaterial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text('İlerleme', style: theme.textTheme.headlineMedium)),
            DecoratedBox(
              decoration: BoxDecoration(color: AppPalette.signalSoft, borderRadius: BorderRadius.circular(999)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'KANITA DAYALI',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppPalette.signal,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.45,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Burada yalnızca aktif öğrenme denemelerinden gelen gerçek durumları görürsün.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.outline),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, color: AppPalette.signal, size: 20),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'İlerleme, bir konuyu kendi başına hatırladığında kaydedilir. Dinleme ve özetler çalışmana yardımcı olur.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Henüz ölçülmüş bir öğrenme durumu yok. Bir materyalde Hatırla ile aktif olarak denediğinde burada görünür.',
              ),
            ),
          )
        else
          for (final item in items) ...[
            _ProgressCard(item: item, onPressed: () => onOpenMaterial(item.material.id)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.item, required this.onPressed});
  final ProgressItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = item.continuation?.state.kind ?? RecallStateKind.notAssessed;
    final label = switch (state) {
      RecallStateKind.notAssessed => 'Henüz ölçülmedi',
      RecallStateKind.developing => 'Gelişiyor',
      RecallStateKind.retrievedOnce => 'Bir kez bağımsız hatırlandı',
      RecallStateKind.needsReview => 'Tekrar gerekiyor',
    };
    final reason = item.continuation?.nextAction.reasonText ?? 'Aktif hatırlama henüz öğrenme kanıtı üretmedi.';
    final (accent, soft, icon) = switch (state) {
      RecallStateKind.notAssessed => (
        AppPalette.inkMuted,
        AppPalette.surfaceMuted,
        Icons.radio_button_unchecked_rounded,
      ),
      RecallStateKind.developing => (AppPalette.primary, AppPalette.primarySoft, Icons.trending_up_rounded),
      RecallStateKind.retrievedOnce => (AppPalette.success, AppPalette.successSoft, Icons.check_circle_rounded),
      RecallStateKind.needsReview => (AppPalette.attention, AppPalette.attentionSoft, Icons.refresh_rounded),
    };
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(icon, color: accent, size: 21),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.material.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(Icons.chevron_right_rounded, color: AppPalette.inkMuted),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppPalette.primaryDark,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(color: AppPalette.momentum, borderRadius: BorderRadius.circular(999)),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.arrow_forward_rounded, color: AppPalette.momentumInk, size: 16),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sıradaki adım',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reason,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
