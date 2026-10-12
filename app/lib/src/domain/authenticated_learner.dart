extension type const LearnerId(String value) {}

enum LearnerIdentityKind { local, authenticated }

class LearnerIdentity {
  const LearnerIdentity({required this.id, this.kind = LearnerIdentityKind.authenticated});

  const LearnerIdentity.authenticated({required this.id}) : kind = LearnerIdentityKind.authenticated;

  const LearnerIdentity.local() : id = const LearnerId('local-device-learner-v1'), kind = LearnerIdentityKind.local;

  final LearnerId id;
  final LearnerIdentityKind kind;

  bool get isLocal => kind == LearnerIdentityKind.local;
  bool get isAuthenticated => kind == LearnerIdentityKind.authenticated;
}

/// Compatibility name for existing authenticated call sites.
///
/// The canonical domain type is [LearnerIdentity]. New local-first code must
/// use [LearnerIdentity.local] rather than presenting a device-local namespace
/// as an authenticated account.
typedef AuthenticatedLearner = LearnerIdentity;
