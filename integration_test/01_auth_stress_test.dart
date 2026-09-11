import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiznenost_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('01. АВТЕНТИКАЦИЯ: Празни полета, пароли и секретен код', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 1. Тест за празен вход
    final loginBtn = find.widgetWithText(ElevatedButton, 'Вход');
    if (loginBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(loginBtn);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();
      expect(find.text('Моля, въведете имейл адрес'), findsOneWidget);
    }

    // 2. Намиране на бутона/линка за регистрация със скролване
    final regFinder = find.byWidgetPredicate(
          (widget) =>
      (widget is Text && widget.data != null && widget.data!.contains('Регистрир')) ||
          (widget is TextButton && widget.child is Text && (widget.child as Text).data!.contains('Регистрир')),
    );

    expect(regFinder, findsAtLeastNWidgets(1), reason: 'Линкът за регистрация не беше намерен.');

    await tester.scrollUntilVisible(
      regFinder.first,
      100.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(regFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 3. Попълване на формата за регистрация
    final nameInputs = find.byType(TextFormField);
    expect(nameInputs, findsAtLeastNWidgets(3));

    final nameField = nameInputs.at(0);
    final emailField = nameInputs.at(1);
    final passField = nameInputs.at(2);

    await tester.enterText(nameField, 'Тест Потребител');
    await tester.enterText(emailField, 'audit_test_2026@zhiznenost.bg');
    await tester.enterText(passField, '123');
    await tester.pumpAndSettle();

    final regSubmitBtn = find.widgetWithText(ElevatedButton, 'Регистрирай се');
    await tester.ensureVisible(regSubmitBtn);
    await tester.tap(regSubmitBtn);
    await tester.pumpAndSettle();

    expect(find.text('Моля, изпълнете всички изисквания за сигурност на паролата.'), findsOneWidget);

    // Скриваме активния SnackBar
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).hideCurrentSnackBar();
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // 4. Превключване към роля Треньор и грешен код
    final coachRoleBtn = find.text('Треньор');
    await tester.ensureVisible(coachRoleBtn);
    await tester.tap(coachRoleBtn);
    await tester.pumpAndSettle();

    final coachCodeInput = find.widgetWithText(TextFormField, 'Секретен код за треньор');
    await tester.ensureVisible(coachCodeInput);
    await tester.enterText(coachCodeInput, 'WRONG_CODE_XYZ');

    await tester.enterText(passField, 'ValidPass2026!');
    await tester.pumpAndSettle();

    await tester.ensureVisible(regSubmitBtn);
    await tester.tap(regSubmitBtn);
    await tester.pumpAndSettle();

    expect(find.text('Невалиден секретен код за треньор! Достъпът е отказан.'), findsOneWidget);
  });
}