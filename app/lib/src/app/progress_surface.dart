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
        Text('İlerleme', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Yalnızca aktif öğrenme kanıtına dayalı durumlar. Dinlemek veya açıklama okumak ilerlemeyi yapay olarak artırmaz.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
    final state = item.continuation?.state.kind ?? RecallStateKind.notAssessed;
    final label = switch (state) {
      RecallStateKind.notAssessed => 'Henüz ölçülmedi',
      RecallStateKind.developing => 'Gelişiyor',
      RecallStateKind.retrievedOnce => 'Bir kez bağımsız hatırlandı',
      RecallStateKind.needsReview => 'Tekrar gerekiyor',
    };
    final reason = item.continuation?.nextAction.reasonText ?? 'Aktif Recall henüz öğrenme kanıtı üretmedi.';
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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sıradaki adım',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Text(reason, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.only(top: 8), child: Icon(Icons.chevron_right_rounded)),
            ],
          ),
        ),
      ),
    );
  }
}
