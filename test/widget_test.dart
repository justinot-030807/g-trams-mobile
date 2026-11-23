import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/features/auth/views/login_screen.dart';
import 'package:gtrams_mobile/features/onboarding/views/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OnboardingScreen renders slides and switches EN/FIL language',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: CivicTheme.light(),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your Digital MTOP & Operator ID'), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);

    await tester.tap(find.text('ENGLISH'));
    await tester.pumpAndSettle();

    expect(find.text('TAGALOG'), findsOneWidget);
    expect(find.text('Digital na MTOP at Operator ID'), findsOneWidget);
  });

  testWidgets('LoginScreen validates empty contact and password cleanly',
      (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: CivicTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('OPERATORS & TODA PRESIDENTS ONLY'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email or mobile number.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });
}
