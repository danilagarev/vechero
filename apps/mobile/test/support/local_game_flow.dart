import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partybox_mobile/src/app.dart';

Future<void> showWidget(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      maxScrolls: 30,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(
  WidgetTester tester,
  Finder finder, {
  bool loadsContent = false,
}) async {
  await showWidget(tester, finder);
  // Wait for deliberately disabled controls (e.g. the handoff tap guard).
  final buttons = find.ancestor(
    of: finder,
    matching: find.byType(FilledButton),
  );
  final nestedButtons = find.descendant(
    of: finder,
    matching: find.byType(FilledButton),
  );
  for (var attempt = 0; attempt < 12; attempt++) {
    final widgets = [
      ...buttons.evaluate(),
      ...nestedButtons.evaluate(),
      ...finder.evaluate(),
    ].map((e) => e.widget).whereType<FilledButton>();
    if (!widgets.any((button) => button.onPressed == null)) break;
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.tap(finder);
  if (loadsContent) {
    await tester.pump();
    // Allow platform asset messages to complete outside the fake async zone.
    for (
      var attempt = 0;
      attempt < 100 &&
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      attempt++
    ) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
    }
  }
  await tester.pumpAndSettle();
}

Future<void> goBack(WidgetTester tester) =>
    tapVisible(tester, find.byType(BackButton).last);

Future<void> prepareGame(WidgetTester tester) async {
  rootBundle.clear();
  await tester.pumpWidget(const PartyBoxApp());
  await tapVisible(tester, find.text('Как играть'));
  await tapVisible(tester, find.text('Собрать компанию'), loadsContent: true);
  for (var i = 0; i < 4; i++) {
    final field = find.byKey(ValueKey('player-name-$i'));
    await showWidget(tester, field);
    await tester.enterText(field, ['Анна', 'Борис', 'Вера', 'Глеб'][i]);
  }
  await tapVisible(tester, find.text('К настройкам'));
  await tapVisible(tester, find.text('Раздать роли'));
}

Future<void> playLocalGame(WidgetTester tester) async {
  await prepareGame(tester);
  var spies = 0;
  final locations = <String>{};
  for (var i = 0; i < 4; i++) {
    expect(find.text('Карточка ${i + 1} из 4'), findsOneWidget);
    expect(find.text('Вы — шпион'), findsNothing);
    expect(find.text('Вы — мирный игрок'), findsNothing);
    await tapVisible(tester, find.text('Показать мою роль'));
    await showWidget(tester, find.byType(Card));
    if (find.text('Вы — шпион').evaluate().isNotEmpty) {
      spies++;
    } else {
      final card = tester.widget<Column>(
        find.descendant(of: find.byType(Card), matching: find.byType(Column)),
      );
      locations.add((card.children.last as Text).data!);
    }
    await tapVisible(tester, find.text('Скрыть и передать'));
  }
  expect(spies, 1);
  expect(locations, hasLength(1));
  expect(find.text('Обсуждение'), findsOneWidget);
  await tapVisible(tester, find.text('Завершить обсуждение'));
  final confirm = find.widgetWithText(FilledButton, 'Подтвердить и раскрыть');
  await showWidget(tester, confirm);
  expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
  await tapVisible(tester, find.text('Анна'));
  await tapVisible(tester, confirm);
  expect(find.textContaining('Шпион: '), findsOneWidget);
  expect(find.textContaining('Локация: '), findsOneWidget);
  await tapVisible(tester, find.text('Ещё раз с теми же игроками'));
  expect(find.text('Передайте телефон: Анна'), findsOneWidget);
  expect(find.text('Карточка 1 из 4'), findsOneWidget);
  expect(find.textContaining('Локация: '), findsNothing);
  // Dispose the periodic timer in widget runs and leave the device at the catalog.
  await goBack(tester);
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Завершить'));
  await goBack(tester);
  await tester.pumpAndSettle();
  expect(find.text('Как играть'), findsOneWidget);
}
