import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app_984/main.dart';
import 'package:my_app_984/screens/welcome_screen.dart';
import 'package:my_app_984/screens/onboarding_screen.dart';

void main() {
  testWidgets('Welcome screen shows loading animation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WelcomeScreen(),
    ));

    expect(find.text('Personal Dashboard'), findsOneWidget);
    expect(find.text('Your Life, Organized'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('Main app always starts with welcome screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(
      isDarkMode: false,
      notificationsEnabled: true,
      isFirstLaunch: false,
    ));

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Personal Dashboard'), findsOneWidget);
    expect(find.text('Your Life, Organized'), findsOneWidget);
  });

  testWidgets('Onboarding screen navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OnboardingScreen(),
    ));

    expect(find.text('Welcome to Personal Dashboard'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Previous'), findsNothing);

    // Test navigation buttons
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });
}
