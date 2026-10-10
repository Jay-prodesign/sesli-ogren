import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sesli_ogren/src/app/account_entry_screen.dart';
import 'package:sesli_ogren/src/domain/authenticated_learner.dart';

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  testWidgets('email OTP entry requests code and opens the verified learner', (tester) async {
    usePhoneViewport(tester);
    String? requestedEmail;
    String? verifiedEmail;
    String? verifiedToken;
    AuthenticatedLearner? openedLearner;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountEntryScreen(
          requestOtp: (email) async {
            requestedEmail = email;
          },
          verifyOtp: ({required email, required token}) async {
            verifiedEmail = email;
            verifiedToken = token;
            return const AuthenticatedLearner(id: LearnerId('account-entry-user'));
          },
          onAuthenticated: (learner) async {
            openedLearner = learner;
          },
        ),
      ),
    );

    expect(find.text('Öğrenme alanına gir'), findsOneWidget);
    expect(find.textContaining('Şifre gerekmiyor'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Test@Example.com');
    await tapVisible(tester, find.text('Kod gönder'));
    await tester.pump();

    expect(requestedEmail, 'Test@Example.com');
    expect(find.text('Kodunu gir'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tapVisible(tester, find.text('Giriş yap'));
    await tester.pump();

    expect(verifiedEmail, 'Test@Example.com');
    expect(verifiedToken, '123456');
    expect(openedLearner?.id.value, 'account-entry-user');
  });

  testWidgets('account entry rejects malformed email before requesting an OTP', (tester) async {
    usePhoneViewport(tester);
    var requestCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountEntryScreen(
          requestOtp: (_) async {
            requestCalls += 1;
          },
          verifyOtp: ({required email, required token}) async =>
              const AuthenticatedLearner(id: LearnerId('never-opened')),
          onAuthenticated: (_) async {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tapVisible(tester, find.text('Kod gönder'));
    await tester.pump();

    expect(find.text('Geçerli bir e-posta adresi gir.'), findsOneWidget);
    expect(requestCalls, 0);
    expect(find.text('Öğrenme alanına gir'), findsOneWidget);
  });

  testWidgets('account entry refuses incomplete OTP before verification', (tester) async {
    usePhoneViewport(tester);
    var verifyCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountEntryScreen(
          requestOtp: (_) async {},
          verifyOtp: ({required email, required token}) async {
            verifyCalls += 1;
            return const AuthenticatedLearner(id: LearnerId('never-opened'));
          },
          onAuthenticated: (_) async {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'person@example.com');
    await tester.tap(find.text('Kod gönder'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Giriş yap'));
    await tester.pump();

    expect(find.text('E-postandaki 6 haneli kodu gir.'), findsOneWidget);
    expect(verifyCalls, 0);
  });
}
