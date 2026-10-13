import 'learning_contracts.dart';

class GroundedTutorThreadId {
  const GroundedTutorThreadId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is GroundedTutorThreadId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class GroundedTutorTurnId {
  const GroundedTutorTurnId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is GroundedTutorTurnId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum GroundedTutorTurnRole { learner, tutor }

enum GroundedTutorSupportState { learnerQuestion, sourceSupported, sourceUnsupported }

class GroundedTutorThreadRecord {
  const GroundedTutorThreadRecord({
    required this.id,
    required this.materialId,
    required this.sourceVersionId,
    required this.contextAnchor,
    required this.createdAt,
    required this.updatedAt,
    required this.invalidatedAt,
  });

  final GroundedTutorThreadId id;
  final MaterialId materialId;
  final SourceVersionId sourceVersionId;
  final SourceAnchor? contextAnchor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? invalidatedAt;

  bool get isCurrent => invalidatedAt == null;
}

class GroundedTutorTurnRecord {
  const GroundedTutorTurnRecord({
    required this.id,
    required this.threadId,
    required this.role,
    required this.text,
    required this.supportState,
    required this.sourceAnchor,
    required this.sourceExcerpt,
    required this.createdAt,
  });

  final GroundedTutorTurnId id;
  final GroundedTutorThreadId threadId;
  final GroundedTutorTurnRole role;
  final String text;
  final GroundedTutorSupportState supportState;
  final SourceAnchor? sourceAnchor;
  final String? sourceExcerpt;
  final DateTime createdAt;

  bool get hasSourceSupport => supportState == GroundedTutorSupportState.sourceSupported;
}

class GroundedTutorThreadState {
  const GroundedTutorThreadState({required this.thread, required this.turns});

  final GroundedTutorThreadRecord thread;
  final List<GroundedTutorTurnRecord> turns;
}
