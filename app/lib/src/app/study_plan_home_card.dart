import 'package:flutter/material.dart';

import '../domain/study_plan.dart';
import 'app_theme.dart';

class StudyPlanHomeCard extends StatelessWidget {
  const StudyPlanHomeCard({required this.projection, required this.hasMaterials, required this.onOpen, super.key});

  final StudyTargetProjection? projection;
  final bool hasMaterials;
  final VoidCallback onOpen;

  String _timing(StudyTargetProjection value) {
    if (value.isPastTarget) return 'Hedef tarihi geçti · sonucu varsaymıyoruz';
    if (value.isTargetToday) return 'Hedef tarihi bugün';
    return '${value.daysUntilTarget} gün kaldı';
  }

  @override
  Widget build(BuildContext context) {
    final value = projection;
    final hasIssue = value?.hasReconciliationIssues == true;
    return Semantics(
      container: true,
      button: true,
      label: value == null
          ? 'Sınav veya çalışma hedefi ekle'
          : 'Çalışma hedefi. ${value.target.title}. ${_timing(value)}. '
                '${hasIssue ? 'Kaynak güncellemesi gerekiyor.' : '${value.currentMaterialCount} güncel kaynak bağlı.'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('home-study-plan'),
          onTap: hasMaterials || value != null ? onOpen : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
            decoration: BoxDecoration(
              color: hasIssue ? AppPalette.attentionSoft : AppPalette.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hasIssue ? AppPalette.attention : AppPalette.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasIssue ? Icons.sync_problem_rounded : Icons.flag_outlined,
                  color: hasIssue ? AppPalette.attention : AppPalette.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: value == null
                      ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SINAV / ÇALIŞMA HEDEFİ',
                              style: TextStyle(
                                color: AppPalette.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Bir hedef tarihi ve kaynaklarını bağla',
                              style: TextStyle(color: AppPalette.ink, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Hedef Today sırasını yalnız eşit önceliklerde düzenler; hazır olma puanı veya günlük kota üretmez.',
                              style: TextStyle(color: AppPalette.inkMuted, fontSize: 11.5, height: 1.35),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasIssue ? 'HEDEF · KAYNAK GÜNCELLE' : 'HEDEF',
                              style: TextStyle(
                                color: hasIssue ? AppPalette.attention : AppPalette.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              value.target.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppPalette.ink, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasIssue
                                  ? '${_timing(value)} · Kaynak bağlarını doğrula'
                                  : '${_timing(value)} · ${value.currentMaterialCount} güncel kaynak',
                              style: const TextStyle(color: AppPalette.inkMuted, fontSize: 11.5, height: 1.35),
                            ),
                          ],
                        ),
                ),
                if (hasMaterials || value != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(Icons.chevron_right_rounded, color: AppPalette.inkMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
