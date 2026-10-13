import 'learning_contracts.dart';

class StudyTargetId {
  const StudyTargetId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is StudyTargetId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class StudyTargetMaterialBinding {
  const StudyTargetMaterialBinding({required this.materialId, required this.sourceVersionId, required this.ordinal});

  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final int ordinal;
}

class StudyTargetRecord {
  StudyTargetRecord({
    required this.id,
    required String title,
    required DateTime targetDate,
    required List<StudyTargetMaterialBinding> materials,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  }) : title = title.trim(),
       targetDate = normalizeDate(targetDate),
       materials = List<StudyTargetMaterialBinding>.unmodifiable(
         [...materials]..sort((left, right) => left.ordinal.compareTo(right.ordinal)),
       );

  final StudyTargetId id;
  final String title;

  /// A calendar target, normalized to a UTC midnight date. It is planning
  /// context only; it never creates evidence, readiness, mastery or urgency.
  final DateTime targetDate;
  final List<StudyTargetMaterialBinding> materials;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get isActive => archivedAt == null;

  static DateTime normalizeDate(DateTime value) => DateTime.utc(value.year, value.month, value.day);
}

enum StudyTargetBindingState { current, sourceChanged, unavailable }

class StudyTargetMaterialStatus {
  const StudyTargetMaterialStatus({
    required this.binding,
    required this.state,
    this.material,
    this.currentSourceVersionId,
  });

  final StudyTargetMaterialBinding binding;
  final StudyTargetBindingState state;
  final MaterialRecord? material;
  final SourceVersionId? currentSourceVersionId;
}

class StudyTargetProjection {
  StudyTargetProjection({
    required this.target,
    required List<StudyTargetMaterialStatus> materials,
    required this.evaluatedAt,
  }) : materials = List<StudyTargetMaterialStatus>.unmodifiable(materials);

  final StudyTargetRecord target;
  final List<StudyTargetMaterialStatus> materials;
  final DateTime evaluatedAt;

  bool get hasReconciliationIssues => materials.any((item) => item.state != StudyTargetBindingState.current);

  int get currentMaterialCount => materials.where((item) => item.state == StudyTargetBindingState.current).length;

  Set<MaterialId> get currentMaterialIds => materials
      .where((item) => item.state == StudyTargetBindingState.current)
      .map((item) => item.binding.materialId)
      .toSet();

  int get daysUntilTarget {
    final today = StudyTargetRecord.normalizeDate(evaluatedAt);
    return target.targetDate.difference(today).inDays;
  }

  bool get isTargetToday => daysUntilTarget == 0;

  bool get isPastTarget => daysUntilTarget < 0;

  static StudyTargetProjection evaluate({
    required StudyTargetRecord target,
    required List<MaterialRecord> activeMaterials,
    required Map<MaterialId, SourceVersionId?> currentSourceVersions,
    required DateTime evaluatedAt,
  }) {
    final active = {for (final item in activeMaterials) item.id: item};
    final statuses = <StudyTargetMaterialStatus>[];
    for (final binding in target.materials) {
      final material = active[binding.materialId];
      final currentSource = currentSourceVersions[binding.materialId];
      if (material == null || !material.isActive || currentSource == null) {
        statuses.add(
          StudyTargetMaterialStatus(
            binding: binding,
            state: StudyTargetBindingState.unavailable,
            material: material,
            currentSourceVersionId: currentSource,
          ),
        );
        continue;
      }
      statuses.add(
        StudyTargetMaterialStatus(
          binding: binding,
          state: currentSource == binding.sourceVersionId
              ? StudyTargetBindingState.current
              : StudyTargetBindingState.sourceChanged,
          material: material,
          currentSourceVersionId: currentSource,
        ),
      );
    }
    return StudyTargetProjection(target: target, materials: statuses, evaluatedAt: evaluatedAt);
  }
}
