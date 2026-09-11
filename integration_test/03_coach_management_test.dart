import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiznenost_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('03. ТРЕНЬОРСКИ ПАНЕЛ: Филтри, Клиенти и Мотивация', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final emailField = find.widgetWithText(TextFormField, 'Имейл адрес');
    final passField = find.widgetWithText(TextFormField, 'Парола');
    final loginBtn = find.widgetWithText(ElevatedButton, 'Вход');

    if (emailField.evaluate().isNotEmpty) {
      await tester.enterText(emailField, 'testcoach@zhiznenost.bg');
      await tester.enterText(passField, 'TestCoach123!');
      await tester.tap(loginBtn);
      await tester.pumpAndSettle(const Duration(seconds: 4));
    }

    // 1. Проверка на табовете
    final coachesTab = find.textContaining('Треньори');
    if (coachesTab.evaluate().isNotEmpty) {
      await tester.tap(coachesTab);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Клиенти'));
      await tester.pumpAndSettle();
    }

    // 2. Тест на редакция на мотивационния цитат
    final editQuoteBtn = find.byIcon(Icons.edit);
    if (editQuoteBtn.evaluate().isNotEmpty) {
      await tester.tap(editQuoteBtn);
      await tester.pumpAndSettle();

      final quoteField = find.widgetWithText(TextFormField, 'Цитат на деня');
      await tester.enterText(quoteField, 'Дисциплината изгражда шампиони!');
      await tester.tap(find.text('Запази'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('Дисциплината изгражда шампиони!'), findsOneWidget);
    }
  });
}