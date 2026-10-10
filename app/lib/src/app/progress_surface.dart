import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'living_study_desk_home.dart';

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
    final living = LivingDeskReviewScope.active(context);
    final accent = living ? AtelierStyle.teal : AppPalette.signal;
    final soft = living ? AtelierStyle.mint : AppPalette.signalSoft;
    final ink = living ? AtelierStyle.ink : theme.colorScheme.onSurface;
    final muted = living ? AtelierStyle.muted : theme.colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        if (living) ...[
          Text(
            'ÖĞRENME KANITIN',
            style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w900, letterSpacing: 0.9),
          ),
          const SizedBox(height: 7),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'İlerleme',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: ink,
                  fontWeight: living ? FontWeight.w900 : null,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  'KANITA DAYALI',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
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
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: living ? AtelierStyle.mint : AppPalette.attentionSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Text(
              'Dinlemek veya açıklama okumak ilerlemeyi yapay olarak artırmaz.',
              style: TextStyle(color: ink),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (items.isEmpty)
          Card(
            elevation: 0,
            color: living ? AtelierStyle.paper : null,
            shape: living
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AtelierStyle.line),
                  )
                : null,
            child: const Padding(
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
    final living = LivingDeskReviewScope.active(context);
    final state = item.continuation?.state.kind ?? RecallStateKind.notAssessed;
    final label = switch (state) {
      RecallStateKind.notAssessed => 'Henüz ölçülmedi',
      RecallStateKind.developing => 'Gelişiyor',
      RecallStateKind.retrievedOnce => 'Bir kez bağımsız hatırlandı',
      RecallStateKind.needsReview => 'Tekrar gerekiyor',
    };
    final reason = item.continuation?.nextAction.reasonText ?? 'Aktif hatırlama henüz öğrenme kanıtı üretmedi.';
    final (legacyAccent, legacySoft, icon) = switch (state) {
      RecallStateKind.notAssessed => (
        AppPalette.inkMuted,
        AppPalette.surfaceMuted,
        Icons.radio_button_unchecked_rounded,
      ),
      RecallStateKind.developing => (AppPalette.primary, AppPalette.primarySoft, Icons.trending_up_rounded),
      RecallStateKind.retrievedOnce => (AppPalette.success, AppPalette.successSoft, Icons.check_circle_rounded),
      RecallStateKind.needsReview => (AppPalette.attention, AppPalette.attentionSoft, Icons.refresh_rounded),
    };
    final accent = living
        ? switch (state) {
            RecallStateKind.notAssessed => AtelierStyle.muted,
            RecallStateKind.developing => AtelierStyle.teal,
            RecallStateKind.retrievedOnce => AtelierStyle.teal,
            RecallStateKind.needsReview => const Color(0xFF9A623E),
          }
        : legacyAccent;
    final soft = living
        ? switch (state) {
            RecallStateKind.notAssessed => AtelierStyle.canvas,
            RecallStateKind.developing => AtelierStyle.mint,
            RecallStateKind.retrievedOnce => AtelierStyle.mint,
            RecallStateKind.needsReview => const Color(0xFFFFF1D9),
          }
        : legacySoft;
    return Card(
      elevation: living ? 0 : null,
      color: living ? AtelierStyle.paper : null,
      shape: living
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AtelierStyle.line),
            )
          : null,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: living ? AtelierStyle.ink : null,
                            fontWeight: FontWeight.w800,
                          ),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(Icons.chevron_right_rounded, color: living ? AtelierStyle.muted : AppPalette.inkMuted),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: living ? AtelierStyle.ink : AppPalette.primaryDark,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: living ? AtelierStyle.mark : AppPalette.momentum,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: living ? AtelierStyle.ink : AppPalette.momentumInk,
                          size: 16,
                        ),
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
