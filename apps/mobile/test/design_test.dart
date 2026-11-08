import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partybox_mobile/src/app.dart';
import 'package:partybox_mobile/src/design/night_components.dart';
import 'package:partybox_mobile/src/design/night_art.dart';
import 'package:partybox_mobile/src/design/night_result_art.dart';
import 'package:partybox_mobile/src/design/night_gallery.dart';
import 'package:partybox_mobile/src/design/night_theme.dart';
import 'package:partybox_mobile/src/spy/local_session_adapter.dart';
import 'package:partybox_mobile/src/spy/spy_game_screen.dart';

import 'support/design_fonts.dart';
import 'support/local_game_flow.dart';

LocalSessionAdapter fixture() => LocalSessionAdapter(
  pack: SpyPack(
    id: 'design',
    version: 1,
    title: 'Базовые локации',
    locations: ['Музей'],
  ),
  random: Random(15),
);

void main() {
  testWidgets('approved design: deterministic complete screen sequence', (
    tester,
  ) async {
    await loadDesignFonts(tester);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    Future<void> capture(String name) => expectLater(
      find.byKey(boundary),
      matchesGoldenFile('../../../docs/design/pb-015/after-$name.png'),
    );
    await tester.pumpWidget(
      RepaintBoundary(key: boundary, child: const PartyBoxApp()),
    );
    await tester.pumpAndSettle();
    await capture('catalog');
    await tapVisible(tester, find.text('Как играть'));
    await capture('rules');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: nightTheme(),
          home: SpyGameScreen(
            adapter: fixture(),
            now: () => DateTime.utc(2026, 11, 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('players');
    for (var i = 0; i < 4; i++) {
      final field = find.byKey(ValueKey('player-name-$i'));
      await showWidget(tester, field);
      await tester.enterText(field, ['Александра', 'Борис', 'Вера', 'Глеб'][i]);
    }
    await tapVisible(tester, find.text('К настройкам'));
    await capture('settings');
    await tapVisible(tester, find.text('Раздать роли'));
    await capture('handoff');
    var capturedCivilian = false;
    String? spyName;
    for (var i = 0; i < 4; i++) {
      await tapVisible(tester, find.text('Показать мою роль'));
      if (find.text('Вы — шпион').evaluate().isNotEmpty) {
        spyName = ['Александра', 'Борис', 'Вера', 'Глеб'][i];
        await capture('spy');
      } else if (!capturedCivilian) {
        capturedCivilian = true;
        await capture('civilian');
      }
      if (i == 0) {
        await goBack(tester);
        await tester.pumpAndSettle();
        expect(find.text('Музей'), findsNothing);
        await capture('exit');
        await tapVisible(tester, find.text('Продолжить игру'));
        await tapVisible(tester, find.text('Показать мою роль'));
      }
      await tapVisible(tester, find.text('Скрыть и передать'));
    }
    await capture('discussion');
    await tapVisible(tester, find.text('Завершить обсуждение'));
    await capture('voting');
    await tapVisible(tester, find.text(spyName!));
    await capture('voting-selected');
    await tapVisible(tester, find.text('Подтвердить и раскрыть'));
    await capture('result-team');
    expect(find.text('Шпион найден!'), findsOneWidget);
    await tapVisible(tester, find.text('Ещё раз с теми же игроками'));
    String? civilianName;
    for (var i = 0; i < 4; i++) {
      await tapVisible(tester, find.text('Показать мою роль'));
      if (find.text('Вы — мирный игрок').evaluate().isNotEmpty) {
        civilianName = ['Александра', 'Борис', 'Вера', 'Глеб'][i];
      }
      await tapVisible(tester, find.text('Скрыть и передать'));
    }
    await tapVisible(tester, find.text('Завершить обсуждение'));
    await tapVisible(tester, find.text(civilianName!));
    await tapVisible(tester, find.text('Подтвердить и раскрыть'));
    await capture('result-spy');
    expect(find.text('Шпион победил!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'secret is removed from text and semantics during interrupted entrance',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: nightTheme(),
          home: SpyGameScreen(adapter: fixture()),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        final field = find.byKey(ValueKey('player-name-$i'));
        await showWidget(tester, field);
        await tester.enterText(field, 'Участник $i');
      }
      await tapVisible(tester, find.text('К настройкам'));
      await tapVisible(tester, find.text('Раздать роли'));
      final reveal = find.byKey(const ValueKey('reveal-role'));
      await showWidget(tester, reveal);
      await tester.tap(reveal);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(Card), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(Card), findsNothing);
      expect(find.text('Музей'), findsNothing);
      final semantics = tester
          .getSemantics(find.byType(SpyGameScreen))
          .toStringDeep();
      expect(semantics, isNot(contains('Музей')));
      expect(semantics, isNot(contains('Вы — шпион')));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reveal-role')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      handle.dispose();
    },
  );

  testWidgets('12 long duplicate names and keyboard fit a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: nightTheme(),
        home: SpyGameScreen(adapter: fixture()),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('player-count')));
    await tester.ensureVisible(find.text('12'));
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    const name = 'Александра-Екатерина с очень длинным именем';
    for (var i = 0; i < 12; i++) {
      final field = find.byKey(ValueKey('player-name-$i'));
      await showWidget(tester, field);
      await tester.enterText(field, name);
    }
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('К настройкам'));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Раздать роли'));
    for (var i = 0; i < 12; i++) {
      await tapVisible(tester, find.text('Показать мою роль'));
      await tapVisible(tester, find.text('Скрыть и передать'));
    }
    await tapVisible(tester, find.text('Завершить обсуждение'));
    await tapVisible(tester, find.byType(RadioListTile<String>).first);
    await tapVisible(tester, find.text('Подтвердить и раскрыть'));
    expect(find.textContaining('Шпион: '), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loading, failure and retry use the same local flow', (
    tester,
  ) async {
    await loadDesignFonts(tester);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final pending = Completer<SpyPack>();
    var attempts = 0;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: nightTheme(),
          home: SpyGameScreen(
            loadPack: () {
              attempts++;
              return attempts == 1
                  ? pending.future
                  : Future.value(fixture().pack);
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('../../../docs/design/pb-015/after-loading.png'),
    );
    pending.completeError(const FormatException('Invalid fixture'));
    await tester.pumpAndSettle();
    expect(find.text('Набор не загрузился'), findsOneWidget);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('../../../docs/design/pb-015/after-error.png'),
    );
    await tapVisible(tester, find.text('Повторить загрузку'));
    expect(attempts, 2);
    expect(find.text('Кто играет?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('iOS keeps the interactive edge back gesture', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(const PartyBoxApp());
    await tapVisible(tester, find.text('Как играть'));
    expect(find.text('Один из вас не в курсе.'), findsOneWidget);
    await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Как играть'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('result animation is interruptible by reduced motion', (
    tester,
  ) async {
    Widget host(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const NightResultArt(kind: NightArtKind.seal),
      ),
    );
    await tester.pumpWidget(host(false));
    expect(tester.widget<NightArt>(find.byType(NightArt)).progress, 0);
    await tester.pump(const Duration(milliseconds: 100));
    final progress = tester.widget<NightArt>(find.byType(NightArt)).progress;
    expect(progress, greaterThan(0));
    expect(progress, lessThan(1));
    await tester.pumpWidget(host(true));
    expect(tester.widget<NightArt>(find.byType(NightArt)).progress, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion renders an entrance immediately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const NightEntrance(child: Text('Готово')),
        ),
      ),
    );
    expect(find.text('Готово'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NightEntrance),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('component gallery fits small screen, large text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: nightTheme(),
        home: const NightGallery(),
      ),
    );
    await tester.pumpAndSettle();
    await showWidget(tester, find.byKey(const ValueKey('gallery-name')));
    await tester.tap(find.byKey(const ValueKey('gallery-name')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Повторить анимацию результата'));
    await tapVisible(tester, find.text('Уменьшить движение'));
    expect(
      tester
          .widget<NightArt>(
            find.descendant(
              of: find.byType(NightResultArt),
              matching: find.byType(NightArt),
            ),
          )
          .progress,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
