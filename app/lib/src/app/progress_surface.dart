import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/learning_truth.dart';

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
        Text('İlerleme', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
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
              child: Text('Henüz ölçülmüş bir öğrenme durumu yok. Bir materyalde Hatırla ile aktif olarak denediğinde burada görünür.'),
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
    return Card(
      elevation: 0,
      child: ListTile(
        onTap: onPressed,
        title: Text(item.material.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(reason, maxLines: 3, overflow: TextOverflow.ellipsis),
          ]),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
