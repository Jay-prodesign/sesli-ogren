import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';
import 'app_theme.dart';
import 'atelier_learning_surfaces.dart';
import 'companion_view.dart';
import 'living_study_desk_home.dart';

class ProgressItem {
  const ProgressItem({
    required this.material,
    required this.continuation,
    this.listenActivityAt,
    this.listenResumeChunk = 0,
    this.readerActivityAt,
    this.readerResumeProgress = 0,
  });
  final MaterialRecord material;
  final LearningContinuation? continuation;
  final DateTime? listenActivityAt;
  final int listenResumeChunk;
  final DateTime? readerActivityAt;
  final double readerResumeProgress;

  bool get hasReaderResume => continuation == null && readerResumeProgress > 0.02 && readerResumeProgress < 0.95;
  bool get hasListenResume => continuation == null && listenResumeChunk > 0;

  bool get prefersReaderResume {
    if (!hasReaderResume) return false;
    if (!hasListenResume) return true;
    if (readerActivityAt == null) return false;
    if (listenActivityAt == null) return true;
    return !readerActivityAt!.isBefore(listenActivityAt!);
  }
}

class ProgressSurface extends StatelessWidget {
  const ProgressSurface({required this.items, required this.onOpenMaterial, this.onAddSource, super.key});

  final List<ProgressItem> items;
  final ValueChanged<MaterialId> onOpenMaterial;
  final VoidCallback? onAddSource;

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
            'HATIRLAMA GEÇMİŞİN',
            style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w900, letterSpacing: 0.9),
          ),
          const SizedBox(height: 7),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final stackHeader = constraints.maxWidth < 340 || MediaQuery.textScalerOf(context).scale(16) >= 22;
            final title = Text(
              'İlerleme',
              style: theme.textTheme.headlineMedium?.copyWith(color: ink, fontWeight: living ? FontWeight.w900 : null),
            );
            final badge = DecoratedBox(
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
            );
            if (stackHeader) {
              return Column(
                key: const ValueKey('progress-header-stacked'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 10), badge],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                badge,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Buradaki durumlar yalnız kaynağa bakmadan yaptığın Hatırla denemelerinden gelir.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 13),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined, color: accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Okumak ve dinlemek hazırlanmandır; ilerlemeyi aktif hatırlama değiştirir.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 18),
            decoration: BoxDecoration(
              color: living ? AtelierStyle.paper : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: living ? AtelierStyle.line : theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const CompanionView(state: CompanionVisualState.idle, size: 64),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İlk hatırlama izini oluştur.',
                            style: theme.textTheme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bir kaynak ekle; sonra kaynağı kapatıp Hatırla ile ilk gerçek denemeni yap.',
                            style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (onAddSource != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onAddSource,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('İlk kaynağımı ekle'),
                    style: living
                        ? FilledButton.styleFrom(backgroundColor: AtelierStyle.ink, foregroundColor: Colors.white)
                        : null,
                  ),
                ],
              ],
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
      RecallStateKind.notAssessed => item.continuation == null ? 'Henüz ölçülmedi' : 'Bağımsız kanıt yok',
      RecallStateKind.developing => 'İpucuyla ilerledi',
      RecallStateKind.retrievedOnce => 'Kendi başına hatırlandı',
      RecallStateKind.needsReview => 'Bir tur daha gerekiyor',
    };
    final reason =
        item.continuation?.nextAction.reasonText ??
        (item.prefersReaderResume
            ? 'Okuma konumun kayıtlı. Devam et; hazır olduğunda kaynağı kapatıp hatırlamayı dene.'
            : item.hasListenResume
            ? 'Dinleme konumun kayıtlı. Devam et; hazır olduğunda kaynağı kapatıp hatırlamayı dene.'
            : 'Henüz bağımsız bir hatırlama denemen yok.');
    final actionLabel = switch (item.continuation?.nextAction.kind) {
      NextLearningActionKind.reviewSourceThenRecall => 'Kaynağı gözden geçir',
      NextLearningActionKind.retryRecallWithoutHint => 'İpucusuz tekrar dene',
      NextLearningActionKind.repeatRecallLater => 'Çalışma alanına dön',
      null when item.prefersReaderResume => 'Okumaya devam et',
      null when item.hasListenResume => 'Dinlemeye devam et',
      null => 'İlk hatırlamayı dene',
    };
    final actionIcon = switch (item.continuation?.nextAction.kind) {
      NextLearningActionKind.reviewSourceThenRecall => Icons.auto_stories_outlined,
      NextLearningActionKind.retryRecallWithoutHint => Icons.refresh_rounded,
      NextLearningActionKind.repeatRecallLater => Icons.space_dashboard_outlined,
      null when item.prefersReaderResume => Icons.menu_book_outlined,
      null when item.hasListenResume => Icons.headphones_rounded,
      null => Icons.psychology_alt_outlined,
    };
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
            RecallStateKind.needsReview => AtelierStyle.attention,
          }
        : legacyAccent;
    final soft = living
        ? switch (state) {
            RecallStateKind.notAssessed => AtelierStyle.canvas,
            RecallStateKind.developing => AtelierStyle.mint,
            RecallStateKind.retrievedOnce => AtelierStyle.mint,
            RecallStateKind.needsReview => AtelierStyle.attentionSoft,
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
        key: ValueKey('progress-continue-${item.material.id.value}'),
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
                        child: Icon(actionIcon, color: living ? AtelierStyle.ink : AppPalette.momentumInk, size: 16),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            actionLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reason,
                            key: ValueKey('progress-next-reason-${item.material.id.value}'),
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
