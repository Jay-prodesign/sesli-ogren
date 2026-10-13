import 'package:flutter/material.dart';

import '../domain/learning_contracts.dart';
import '../domain/study_plan.dart';
import 'app_runtime.dart';
import 'app_theme.dart';
import 'companion_view.dart';
import 'living_study_desk_home.dart';

class StudyPlanHomeCard extends StatelessWidget {
  const StudyPlanHomeCard({
    required this.projection,
    required this.hasMaterials,
    required this.onOpen,
    super.key,
  });

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

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({required this.runtime, super.key});

  final AppRuntime runtime;

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  late Future<_StudyPlanData> _future;
  final _titleController = TextEditingController();
  final Set<MaterialId> _selected = <MaterialId>{};
  DateTime? _selectedDate;
  bool _editing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<_StudyPlanData> _load() async {
    final evaluatedAt = DateTime.now().toUtc();
    final target = await widget.runtime.store.activeStudyTarget(learner: widget.runtime.learner);
    final materials = await widget.runtime.store.activeMaterials(learner: widget.runtime.learner);
    final choices = <_StudyMaterialChoice>[];
    final currentSources = <MaterialId, SourceVersionId?>{};
    for (final material in materials) {
      final source = await widget.runtime.store.currentSourceVersion(
        learner: widget.runtime.learner,
        materialId: material.id,
      );
      currentSources[material.id] = source?.identity.sourceVersionId;
      choices.add(_StudyMaterialChoice(material: material, sourceVersionId: source?.identity.sourceVersionId));
    }
    final projection = target == null
        ? null
        : StudyTargetProjection.evaluate(
            target: target,
            activeMaterials: materials,
            currentSourceVersions: currentSources,
            evaluatedAt: evaluatedAt,
          );
    return _StudyPlanData(target: target, projection: projection, choices: choices, evaluatedAt: evaluatedAt);
  }

  void _reload() {
    setState(() {
      _editing = false;
      _busy = false;
      _error = null;
      _selected.clear();
      _selectedDate = null;
      _titleController.clear();
      _future = _load();
    });
  }

  void _beginEdit(_StudyPlanData data) {
    final target = data.target;
    _titleController.text = target?.title ?? '';
    _selectedDate = target?.targetDate;
    _selected
      ..clear()
      ..addAll(target?.materials.map((item) => item.materialId) ?? const <MaterialId>[]);
    setState(() {
      _editing = true;
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year, now.month, now.day)
          : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Hedef tarihini seç',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedDate = selected;
      _error = null;
    });
  }

  Future<void> _save(_StudyPlanData data) async {
    if (_busy) return;
    final title = _titleController.text.trim();
    final date = _selectedDate;
    final selectedChoices = data.choices
        .where(
          (item) =>
              _selected.contains(item.material.id) &&
              item.sourceVersionId != null &&
              item.material.processingState == MaterialProcessingState.ready,
        )
        .toList(growable: false);
    final today = StudyTargetRecord.normalizeDate(DateTime.now());
    if (title.isEmpty) {
      setState(() => _error = 'Hedefe kısa bir ad ver.');
      return;
    }
    if (date == null) {
      setState(() => _error = 'Hedef tarihini seç.');
      return;
    }
    if (StudyTargetRecord.normalizeDate(date).isBefore(today)) {
      setState(() => _error = 'Yeni hedef tarihi bugün veya daha sonra olmalı.');
      return;
    }
    if (selectedChoices.isEmpty) {
      setState(() => _error = 'En az bir güncel ve hazır kaynak seç.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final now = DateTime.now().toUtc();
    final existing = data.target;
    try {
      await widget.runtime.store.saveStudyTarget(
        learner: widget.runtime.learner,
        target: StudyTargetRecord(
          id: existing?.id ?? StudyTargetId('study_target_${now.microsecondsSinceEpoch}'),
          title: title,
          targetDate: date,
          materials: [
            for (var index = 0; index < selectedChoices.length; index++)
              StudyTargetMaterialBinding(
                materialId: selectedChoices[index].material.id,
                sourceVersionId: selectedChoices[index].sourceVersionId!,
                ordinal: index,
              ),
          ],
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Plan kaydedilemedi. Kaynaklardan biri değişmiş olabilir; güncel kaynakları yeniden kontrol et.';
        _future = _load();
      });
    }
  }

  Future<void> _archive(StudyTargetRecord target) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bu hedefi kapat?'),
        content: const Text(
          'Hedef planından çıkarılacak. Öğrenme kanıtların, materyallerin ve planlanan tekrarların silinmez.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Hedefi kapat')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await widget.runtime.store.archiveStudyTarget(
      learner: widget.runtime.learner,
      targetId: target.id,
      archivedAt: DateTime.now().toUtc(),
    );
    if (!mounted) return;
    _reload();
  }

  String _dateLabel(DateTime date) {
    const months = <String>[
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _timing(StudyTargetProjection projection) {
    if (projection.isPastTarget) return 'Hedef tarihi geçti. Sınav sonucunu veya hazır oluşunu varsaymıyoruz.';
    if (projection.isTargetToday) return 'Hedef tarihi bugün. Takvim tarihi tek başına hazır olduğun anlamına gelmez.';
    return '${projection.daysUntilTarget} gün kaldı. Bu yalnız takvim bilgisidir; hazır olma puanı değildir.';
  }

  @override
  Widget build(BuildContext context) {
    final living = LivingDeskReviewScope.active(context);
    return Scaffold(
      key: const ValueKey('study-plan-screen'),
      backgroundColor: living ? AtelierStyle.canvas : null,
      appBar: AppBar(
        title: const Text('Sınav / Çalışma Planı'),
        backgroundColor: living ? AtelierStyle.canvas : null,
      ),
      body: SafeArea(
        child: FutureBuilder<_StudyPlanData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const _StudyPlanLoading();
            if (snapshot.hasError || !snapshot.hasData) {
              return _StudyPlanError(onRetry: _reload);
            }
            final data = snapshot.data!;
            if (_editing) return _editor(data);
            if (data.target == null) return _empty(data);
            return _summary(data);
          },
        ),
      ),
    );
  }

  Widget _empty(_StudyPlanData data) {
    final canCreate = data.choices.any(
      (item) => item.sourceVersionId != null && item.material.processingState == MaterialProcessingState.ready,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      children: [
        const CompanionView(state: CompanionVisualState.think, size: 82),
        const SizedBox(height: 14),
        const Text(
          'Hedef tarihini bağla; öğrenme gerçeğini değiştirme.',
          style: TextStyle(color: AtelierStyle.ink, fontSize: 26, height: 1.08, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 9),
        const Text(
          'Plan, seçtiğin güncel kaynakları Today sırasında eşit öncelikler arasında öne alır. '
          'Saat kotası, hazır olma yüzdesi veya sınav başarısı tahmini üretmez.',
          style: TextStyle(color: AtelierStyle.muted, height: 1.45),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('study-plan-create'),
          onPressed: canCreate ? () => _beginEdit(data) : null,
          icon: const Icon(Icons.flag_outlined),
          label: Text(canCreate ? 'Hedef oluştur' : 'Önce hazır bir kaynak ekle'),
        ),
      ],
    );
  }

  Widget _summary(_StudyPlanData data) {
    final projection = data.projection!;
    final issues = projection.materials.where((item) => item.state != StudyTargetBindingState.current).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        const Text(
          'ÇALIŞMA HEDEFİN',
          style: TextStyle(color: AtelierStyle.pulse, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.9),
        ),
        const SizedBox(height: 7),
        Text(
          projection.target.title,
          style: const TextStyle(color: AtelierStyle.ink, fontSize: 28, height: 1.05, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '${_dateLabel(projection.target.targetDate)} · ${_timing(projection)}',
          style: const TextStyle(color: AtelierStyle.muted, height: 1.42),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: issues > 0 ? AppPalette.attentionSoft : AtelierStyle.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: issues > 0 ? AppPalette.attention : AtelierStyle.line),
          ),
          child: Text(
            issues > 0
                ? '$issues kaynak bağının güncel sürümle yeniden doğrulanması gerekiyor. Eski sürümden yeni görev üretmiyoruz.'
                : '${projection.currentMaterialCount} kaynak güncel. Today bu hedefi yalnız eşit öğrenme önceliklerinde tie-break olarak kullanıyor.',
            style: const TextStyle(color: AtelierStyle.ink, height: 1.4),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Kaynak kapsamı', style: TextStyle(color: AtelierStyle.ink, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final item in projection.materials) ...[
          _materialStatus(item),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('study-plan-primary'),
          onPressed: projection.hasReconciliationIssues || projection.isPastTarget
              ? () => _beginEdit(data)
              : () => Navigator.of(context).maybePop(),
          icon: Icon(
            projection.hasReconciliationIssues || projection.isPastTarget
                ? Icons.edit_calendar_outlined
                : Icons.today_outlined,
          ),
          label: Text(
            projection.hasReconciliationIssues
                ? 'Planı güncel kaynaklara bağla'
                : projection.isPastTarget
                ? 'Hedef tarihini güncelle'
                : 'Bugünkü plana dön',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('study-plan-edit'),
          onPressed: _busy ? null : () => _beginEdit(data),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Planı düzenle'),
        ),
        TextButton(
          key: const ValueKey('study-plan-archive'),
          onPressed: _busy ? null : () => _archive(projection.target),
          child: const Text('Hedefi kapat'),
        ),
      ],
    );
  }

  Widget _materialStatus(StudyTargetMaterialStatus item) {
    final title = item.material?.title ?? 'Artık kullanılamayan materyal';
    final (label, icon, color) = switch (item.state) {
      StudyTargetBindingState.current => ('Güncel kaynak', Icons.verified_outlined, AppPalette.success),
      StudyTargetBindingState.sourceChanged => ('Kaynak değişti', Icons.sync_problem_rounded, AppPalette.attention),
      StudyTargetBindingState.unavailable => ('Kaynak kullanılamıyor', Icons.block_outlined, AppPalette.attention),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AtelierStyle.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AtelierStyle.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editor(_StudyPlanData data) {
    final available = data.choices
        .where((item) => item.sourceVersionId != null && item.material.processingState == MaterialProcessingState.ready)
        .toList(growable: false);
    return ListView(
      key: const ValueKey('study-plan-editor'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        Text(
          data.target == null ? 'Yeni hedef' : 'Hedefi güncelle',
          style: const TextStyle(color: AtelierStyle.ink, fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          'Kaynak sürümü değişmişse kaydetmek, seçili materyali açıkça güncel sürüme yeniden bağlar.',
          style: TextStyle(color: AtelierStyle.muted, height: 1.42),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('study-plan-title'),
          controller: _titleController,
          maxLength: 120,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Hedef adı', hintText: 'Örn. Fizik ara sınavı'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('study-plan-date'),
          onPressed: _busy ? null : _pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(_selectedDate == null ? 'Hedef tarihini seç' : _dateLabel(_selectedDate!)),
        ),
        const SizedBox(height: 18),
        const Text('Bu hedefe bağlı kaynaklar', style: TextStyle(color: AtelierStyle.ink, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        if (available.isEmpty)
          const Text(
            'Planlanabilecek güncel ve hazır bir kaynak yok.',
            style: TextStyle(color: AtelierStyle.muted),
          )
        else
          for (final item in available)
            CheckboxListTile(
              key: ValueKey('study-plan-material-${item.material.id.value}'),
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(item.material.id),
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(item.material.id);
                        } else {
                          _selected.remove(item.material.id);
                        }
                        _error = null;
                      });
                    },
              title: Text(item.material.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Güncel kaynak sürümüne bağlanır'),
            ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, key: const ValueKey('study-plan-error'), style: const TextStyle(color: AppPalette.attention)),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('study-plan-save'),
          onPressed: _busy ? null : () => _save(data),
          icon: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_rounded),
          label: Text(_busy ? 'Kaydediliyor…' : 'Planı kaydet'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  setState(() {
                    _editing = false;
                    _error = null;
                  });
                },
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}

class _StudyPlanData {
  const _StudyPlanData({
    required this.target,
    required this.projection,
    required this.choices,
    required this.evaluatedAt,
  });

  final StudyTargetRecord? target;
  final StudyTargetProjection? projection;
  final List<_StudyMaterialChoice> choices;
  final DateTime evaluatedAt;
}

class _StudyMaterialChoice {
  const _StudyMaterialChoice({required this.material, required this.sourceVersionId});

  final MaterialRecord material;
  final SourceVersionId? sourceVersionId;
}

class _StudyPlanLoading extends StatelessWidget {
  const _StudyPlanLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompanionView(state: CompanionVisualState.think, size: 72),
        SizedBox(height: 12),
        Text('Planın güncel kaynaklarla doğrulanıyor…'),
      ],
    ),
  );
}

class _StudyPlanError extends StatelessWidget {
  const _StudyPlanError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CompanionView(state: CompanionVisualState.think, size: 72),
          const SizedBox(height: 12),
          const Text('Plan açılamadı. Öğrenme durumunu tahmin etmiyoruz.', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Tekrar dene')),
        ],
      ),
    ),
  );
}
