import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiznenost_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ЖИЗНЕНОСТ - ПЪЛЕН АВТОМАТИЗИРАН СТРЕС ТЕСТ', () {
    testWidgets('Пълен цикъл: Регистрация, Валидации, Дневник, Прогрес и Панели', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // -------------------------------------------------------------
      // ЕТАП 1: ТЕСТ НА ВХОД И ПРАЗНИ ВАЛИДАЦИИ
      // -------------------------------------------------------------
      final loginBtn = find.widgetWithText(ElevatedButton, 'Вход');
      if (loginBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(loginBtn);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();

        expect(find.text('Моля, въведете имейл адрес'), findsOneWidget);
        expect(find.text('Моля, въведете парола'), findsOneWidget);
      }

      // -------------------------------------------------------------
      // ЕТАП 2: ТЕСТ НА РЕГИСТРАЦИЯ И СИГУРНОСТ НА ПАРОЛИ
      // -------------------------------------------------------------
      final registerLink = find.text('Регистрирай се');
      if (registerLink.evaluate().isNotEmpty) {
        await tester.ensureVisible(registerLink);
        await tester.tap(registerLink);
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(TextFormField, 'Име и фамилия');
        final emailField = find.widgetWithText(TextFormField, 'Имейл');
        final passField = find.widgetWithText(TextFormField, 'Парола');
        final submitRegBtn = find.widgetWithText(ElevatedButton, 'Регистрирай се');

        // 1. Попълваме коректни име и имейл, но слаба парола "1234"
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, 'Тестов Потребител');

        await tester.ensureVisible(emailField);
        await tester.enterText(emailField, 'tester2026@zhiznenost.bg');

        await tester.ensureVisible(passField);
        await tester.enterText(passField, '1234');
        await tester.pumpAndSettle();

        // 2. Опит за регистрация - формата минава, но паролата се спира от проверката
        await tester.ensureVisible(submitRegBtn);
        await tester.tap(submitRegBtn);
        await tester.pumpAndSettle();

        expect(find.text('Моля, изпълнете всички изисквания за сигурност на паролата.'), findsOneWidget);

        // 3. Тест на невалиден секретен код за треньор
        final coachRoleBtn = find.text('Треньор');
        if (coachRoleBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(coachRoleBtn);
          await tester.tap(coachRoleBtn);
          await tester.pumpAndSettle();

          final codeField = find.widgetWithText(TextFormField, 'Секретен код за треньор');
          if (codeField.evaluate().isNotEmpty) {
            await tester.ensureVisible(codeField);
            await tester.enterText(codeField, 'WRONG_CODE_999');

            // Въвеждаме напълно валидна силна парола
            await tester.ensureVisible(passField);
            await tester.enterText(passField, 'ZhiznenostPass2026!');
            await tester.pumpAndSettle();

            await tester.ensureVisible(submitRegBtn);
            await tester.tap(submitRegBtn);
            await tester.pumpAndSettle();

            expect(find.text('Невалиден секретен код за треньор! Достъпът е отказан.'), findsOneWidget);
          }
        }

        // Връщане към началния екран за вход
        final backBtn = find.byIcon(Icons.arrow_back_ios_new);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn);
          await tester.pumpAndSettle();
        }
      }

      // -------------------------------------------------------------
      // ЕТАП 3: ТЕСТ НА ДНЕВНИК (ПРИ НАЛИЧЕН ТАБ / ИНДИВИДУАЛНА КАРТА)
      // -------------------------------------------------------------
      final diaryNavBtn = find.byIcon(Icons.fitness_center);
      if (diaryNavBtn.evaluate().isNotEmpty) {
        await tester.tap(diaryNavBtn);
        await tester.pumpAndSettle();

        final exerciseInputs = find.byType(TextField);
        if (exerciseInputs.evaluate().length >= 3) {
          await tester.enterText(exerciseInputs.at(0), 'Лежанка стрес тест');
          await tester.enterText(exerciseInputs.at(1), '92,5'); // българска запетая
          await tester.enterText(exerciseInputs.at(2), '8');
          await tester.pumpAndSettle();

          final addSetBtn = find.text('Добави серия');
          if (addSetBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(addSetBtn);
            await tester.tap(addSetBtn);
            await tester.pumpAndSettle();

            expect(find.textContaining('92.5 кг x 8 повт.'), findsOneWidget);
          }

          final saveExerciseBtn = find.text('Запази цялото упражнение');
          if (saveExerciseBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(saveExerciseBtn);
            for (int i = 0; i < 3; i++) {
              await tester.tap(saveExerciseBtn, warnIfMissed: false);
            }
            await tester.pump(const Duration(milliseconds: 100));
            await tester.pumpAndSettle(const Duration(seconds: 4));
          }
        }
      }

      // -------------------------------------------------------------
      // ЕТАП 4: ТЕСТ НА РЕЗУЛТАТИ И СПОРТЕН ПРОГРЕС
      // -------------------------------------------------------------
      final progressNavBtn = find.byIcon(Icons.trending_up);
      if (progressNavBtn.evaluate().isNotEmpty) {
        await tester.tap(progressNavBtn);
        await tester.pumpAndSettle();

        final weightInputs = find.byType(TextField);
        if (weightInputs.evaluate().isNotEmpty) {
          await tester.enterText(weightInputs.first, '450');
          final saveMetricBtn = find.text('Запази резултатите');

          if (saveMetricBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(saveMetricBtn);
            await tester.tap(saveMetricBtn);
            await tester.pumpAndSettle();
            expect(find.text('Въведете реално тегло между 30 и 300 кг!'), findsOneWidget);
          }
        }
      }
    });
  });
}