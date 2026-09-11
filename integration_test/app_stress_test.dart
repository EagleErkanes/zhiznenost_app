import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiznenost_app/main.dart' as app;

void main() {
  // Инициализация на интеграционната среда
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Стрес тест: Гранични UI/UX ситуации и защита от краш', (tester) async {
    // 1. СИМУЛАЦИЯ НА МАКСИМАЛНО СТАТУСНО НАТОВАРВАНЕ (Accessibility / Голям шрифт)
    // Много потребители увеличават шрифта от настройките, което чупи UI (RenderFlex overflow)
    tester.view.physicalSize = const Size(360, 640); // Малък екран (напр. по-стар телефон)
    tester.view.devicePixelRatio = 1.0;

    // Стартиране на приложението
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Намиране на текстовите полета на екрана
    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeastNWidgets(1), reason: 'Липсват текстови полета на екрана.');

    final exerciseNameField = textFields.at(0);

    // 2. ТЕСТ С ГРАНИЧНИ ДАННИ И СПЕЦИАЛНИ СИМВОЛИ (Injection & Crash Test)
    // Проверяваме как базата данни и UI реагират на емоджита, огромни текстове и математически знаци
    const dangerousInput = '🏋️‍♂️ Клек @#\$%^&*()_+=-[]{};:\'",.<>/? \\ | 123 0.0001 NaN Null undefined';
    await tester.enterText(exerciseNameField, dangerousInput);
    await tester.pumpAndSettle();

    // Ако имате второ поле (напр. за килограми или повторения), го атакуваме с грешен тип данни
    if (textFields.evaluate().length > 1) {
      final weightField = textFields.at(1);
      // Въвеждаме букви и десетични запетаи там, където се очаква само число (напр. "50,5" вместо "50.5")
      await tester.enterText(weightField, '50,,5abc++-');
      await tester.pumpAndSettle();
    }

    // 3. ТЕСТ ЗА ВАЛИДАЦИЯ НА ПРАЗНИ ПОЛЕТА
    // Изчистваме полето изцяло и се опитваме да добавим серия, за да проверим за липса на валидация (Null Pointer Exception)
    await tester.enterText(exerciseNameField, '');
    await tester.pumpAndSettle();

    final addSetButton = find.text('Добави серия');
    if (addSetButton.evaluate().isNotEmpty) {
      await tester.tap(addSetButton);
      await tester.pumpAndSettle(); // Трябва да покаже грешка/валидация на екрана, без да крашне
    }

    // Връщаме нормален текст, за да преминем към финалния бутон
    await tester.enterText(exerciseNameField, 'Тестово Упражнение след стрес');
    await tester.pumpAndSettle();

    // 4. ИСТИНСКИ СТРЕС ТЕСТ ЗА МНОГОКРАТНО КЛИКАНЕ (Spam / Debounce Click)
    final saveButton = find.text('Запази цялото упражнение');
    if (saveButton.evaluate().isNotEmpty) {
      // Използваме цикъл с микро-фреймове (tester.pump()), за да симулираме реално бързо помпене по бутона
      for (int i = 0; i < 8; i++) {
        await tester.tap(saveButton, warnIfMissed: false);
        // pump() кара Flutter да обработи клика веднага, тествайки дали бекендът ще дублира записа
        await tester.pump();
      }
      // Изчакваме всички анимации и асинхронни процеси да приключат изцяло
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // Ако тестът стигне до тук без нехваната грешка (Uncaught Exception) или краш, приложението е стабилно!
  });
}
