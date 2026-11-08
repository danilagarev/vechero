import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partybox_mobile/src/spy/local_session_adapter.dart';
import 'package:partybox_mobile/src/spy/spy_game_screen.dart';

import 'support/local_game_flow.dart';

void main() {
  testWidgets('complete local game and replay', playLocalGame);

  testWidgets('full cycle fits a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await playLocalGame(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discussion resumes from deadline and moves to voting after absence',
    (tester) async {
      var now = DateTime.utc(2026, 11, 8);
      await tester.pumpWidget(
        MaterialApp(
          home: SpyGameScreen(
            adapter: LocalSessionAdapter(
              pack: SpyPack(
                id: 'test',
                version: 1,
                title: 'Тест',
                locations: ['Музей'],
              ),
            ),
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        final field = find.byKey(ValueKey('player-name-$i'));
        await tester.ensureVisible(field);
        await tester.enterText(field, 'Участник $i');
      }
      await tapVisible(tester, find.text('К настройкам'));
      await tapVisible(tester, find.text('Раздать роли'));
      for (var i = 0; i < 4; i++) {
        await tapVisible(tester, find.text('Показать мою роль'));
        await tapVisible(tester, find.text('Скрыть и передать'));
      }
      expect(find.text('5:00'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 61));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('3:59'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Кого подозревает компания?'), findsOneWidget);
      expect(find.textContaining('Локация:'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('double tap cannot skip a player; background conceals a card', (
    tester,
  ) async {
    await prepareGame(tester);
    await tapVisible(tester, find.text('Показать мою роль'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(Card), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Показать мою роль'), findsOneWidget);
    expect(find.text('Карточка 1 из 4'), findsOneWidget);
    await tapVisible(tester, find.text('Показать мою роль'));
    final handoff = find.text('Скрыть и передать');
    await tester.ensureVisible(handoff);
    await tester.tap(handoff);
    await tester.tap(handoff);
    await tester.pumpAndSettle();
    expect(find.text('Карточка 2 из 4'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    await tapVisible(tester, find.text('Показать мою роль'));
    await goBack(tester);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Продолжить игру'));
    expect(find.text('Карточка 2 из 4'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('blank names are rejected and preparation can be cancelled', (
    tester,
  ) async {
    // Navigate without entering any names.
    await prepareGame(tester);
    await goBack(tester);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Завершить'));
    await tapVisible(tester, find.text('Собрать компанию'), loadsContent: true);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('К настройкам'));
    expect(find.text('Настройки партии'), findsNothing);
    await tapVisible(tester, find.text('Отменить подготовку'));
    expect(find.text('Собрать компанию'), findsOneWidget);
  });
}
