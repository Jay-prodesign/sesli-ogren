import 'package:flutter/widgets.dart';

/// Compatibility wrapper retained while older local databases still carry the
/// historical onboarding-completion field.
///
/// The product no longer blocks first value behind a feature tour. After
/// authentication the learner lands directly on the real empty Home surface,
/// whose primary action is to add their first PDF/text material.
class FirstRunOnboardingGate extends StatelessWidget {
  const FirstRunOnboardingGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
