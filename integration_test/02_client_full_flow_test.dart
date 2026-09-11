import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiznenost_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('02. КЛИЕНТСКИ ПОТОК: Дневник, Спам кликове и Символи', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Вход с тестови данни (Замени с реален тестов клиент от твоя Supabase)
    final emailField = find.widgetWithText(TextFormField, 'Имейл адрес');
    final passField = find.widgetWithText(TextFormField, 'Парола');
    final loginBtn = find.widgetWithText(ElevatedButton, 'Вход');

    if (emailField.evaluate().isNotEmpty) {
      await tester.enterText(emailField, 'testclient@zhiznenost.bg');
      await tester.enterText(passField, 'TestClient123!');
      await tester.tap(loginBtn);
      await tester.pumpAndSettle(const Duration(seconds: 4));
    }

    // 1. Преминаване към таб Дневник
    final diaryTab = find.byIcon(Icons.fitness_center);
    if (diaryTab.evaluate().isNotEmpty) {
      await tester.tap(diaryTab);
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(2));

      // Стрес тест със специални знаци от source: 1
      const dangerousInput = '🏋️‍♂️ Клек @#\$%^&*()_+=-[]{};:\'",.<>/? \\ | 123';
      await tester.enterText(textFields.at(0), dangerousInput);
      await tester.enterText(textFields.at(1), '82,5'); // българска запетая
      await tester.enterText(textFields.at(2), '8');
      await tester.pumpAndSettle();

      final addSetBtn = find.text('Добави серия');
      await tester.ensureVisible(addSetBtn);
      await tester.tap(addSetBtn);
      await tester.pumpAndSettle();

      // Стрес тест за спам кликане (Debounce / Double submission защита) от source: 1
      final saveBtn = find.text('Запази цялото упражнение');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(saveBtn);
        for (int i = 0; i < 5; i++) {
          await tester.tap(saveBtn, warnIfMissed: false);
          await tester.pump();
        }
        await tester.pumpAndSettle(const Duration(seconds: 4));
      }
    }
  });
}