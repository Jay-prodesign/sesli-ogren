import 'learning_contracts.dart';

class RetentionScheduleId {
  const RetentionScheduleId(this.value);

  final String value;

  @override
  bool operator ==(Object other) => other is RetentionScheduleId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum RetentionEvidenceKind { recall, flashcard, quiz }

enum RetentionOutcomeBand { independentRetrieval, supportedRetrieval, repairNeeded, unassessed }

class RetentionScheduleRecord {
  const RetentionScheduleRecord({
    required this.id,
    required this.materialId,
    required this.sourceVersionId,
    required this.sourceAnchor,
    required this.latestEvidenceKind,
    required this.latestOutcomeBand,
    required this.latestEventId,
    required this.reasonCode,
    required this.reviewCount,
    required this.successStreak,
    required this.interval,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.policyVersion,
  });

  final RetentionScheduleId id;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final SourceAnchor sourceAnchor;
  final RetentionEvidenceKind latestEvidenceKind;
  final RetentionOutcomeBand latestOutcomeBand;

  /// Stable durable event lineage. Replaying the same event never advances a
  /// schedule twice.
  final String latestEventId;

  /// Explainable scheduling reason, never a mastery label or percentage.
  final String reasonCode;
  final int reviewCount;
  final int successStreak;
  final Duration interval;
  final DateTime dueAt;
  final DateTime lastReviewedAt;
  final String policyVersion;

  bool isDueAt(DateTime instant) => !dueAt.isAfter(instant.toUtc());
}

class RetentionMaterialStatus {
  RetentionMaterialStatus({
    required List<RetentionScheduleRecord> schedules,
    required DateTime evaluatedAt,
  }) : schedules = List<RetentionScheduleRecord>.unmodifiable(
         [...schedules]..sort((left, right) => left.dueAt.compareTo(right.dueAt)),
       ),
       evaluatedAt = evaluatedAt.toUtc();

  final List<RetentionScheduleRecord> schedules;
  final DateTime evaluatedAt;

  bool get hasSchedule => schedules.isNotEmpty;

  int get dueCount => schedules.where((item) => item.isDueAt(evaluatedAt)).length;

  bool get hasDue => dueCount > 0;

  RetentionScheduleRecord? get nextScheduled => schedules.isEmpty ? null : schedules.first;

  RetentionScheduleRecord? get nextDue {
    for (final item in schedules) {
      if (item.isDueAt(evaluatedAt)) return item;
    }
    return null;
  }

  DateTime? get latestReviewedAt {
    DateTime? latest;
    for (final item in schedules) {
      if (latest == null || item.lastReviewedAt.isAfter(latest)) {
        latest = item.lastReviewedAt;
      }
    }
    return latest;
  }
}

class RetentionPolicy {
  const RetentionPolicy._();

  static const version = 'retention-v1';

  static RetentionScheduleRecord advance({
    required RetentionScheduleRecord? existing,
    required RetentionScheduleId id,
    required MaterialId materialId,
    required SourceVersionId sourceVersionId,
    required SourceAnchor sourceAnchor,
    required RetentionEvidenceKind evidenceKind,
    required RetentionOutcomeBand outcomeBand,
    required String eventId,
    required DateTime occurredAt,
  }) {
    final at = occurredAt.toUtc();
    if (sourceAnchor.startOffset < 0 || sourceAnchor.endOffset <= sourceAnchor.startOffset) {
      throw ArgumentError.value(sourceAnchor, 'sourceAnchor', 'Retention requires a bounded source anchor.');
    }
    if (eventId.trim().isEmpty) {
      throw ArgumentError.value(eventId, 'eventId', 'Retention requires durable event lineage.');
    }
    if (existing != null) {
      if (existing.id != id ||
          existing.materialId != materialId ||
          existing.sourceVersionId != sourceVersionId ||
          existing.sourceAnchor.startOffset != sourceAnchor.startOffset ||
          existing.sourceAnchor.endOffset != sourceAnchor.endOffset ||
          existing.sourceAnchor.pageNumber != sourceAnchor.pageNumber) {
        throw ArgumentError('Retention schedule lineage cannot cross a material, source version, or source anchor.');
      }
      if (existing.latestEventId == eventId) return existing;
      if (at.isBefore(existing.lastReviewedAt)) {
        throw ArgumentError('Retention events must advance in durable chronological order.');
      }
    }

    final successStreak = outcomeBand == RetentionOutcomeBand.independentRetrieval
        ? (existing?.successStreak ?? 0) + 1
        : 0;
    final interval = _intervalFor(outcomeBand: outcomeBand, successStreak: successStreak);
    final reasonCode = switch (outcomeBand) {
      RetentionOutcomeBand.independentRetrieval => 'INDEPENDENT_RETRIEVAL_OBSERVED',
      RetentionOutcomeBand.supportedRetrieval => 'SUPPORTED_OR_PARTIAL_RETRIEVAL',
      RetentionOutcomeBand.repairNeeded => 'RETRIEVAL_REPAIR_NEEDED',
      RetentionOutcomeBand.unassessed => 'NO_POSITIVE_RETENTION_EVIDENCE',
    };

    return RetentionScheduleRecord(
      id: id,
      materialId: materialId,
      sourceVersionId: sourceVersionId,
      sourceAnchor: sourceAnchor,
      latestEvidenceKind: evidenceKind,
      latestOutcomeBand: outcomeBand,
      latestEventId: eventId,
      reasonCode: reasonCode,
      reviewCount: (existing?.reviewCount ?? 0) + 1,
      successStreak: successStreak,
      interval: interval,
      dueAt: at.add(interval),
      lastReviewedAt: at,
      policyVersion: version,
    );
  }

  static Duration _intervalFor({required RetentionOutcomeBand outcomeBand, required int successStreak}) {
    return switch (outcomeBand) {
      RetentionOutcomeBand.independentRetrieval => switch (successStreak) {
        <= 1 => const Duration(days: 1),
        2 => const Duration(days: 3),
        3 => const Duration(days: 7),
        4 => const Duration(days: 14),
        _ => const Duration(days: 30),
      },
      RetentionOutcomeBand.supportedRetrieval => const Duration(hours: 12),
      RetentionOutcomeBand.repairNeeded => const Duration(minutes: 10),
      RetentionOutcomeBand.unassessed => Duration.zero,
    };
  }
}
