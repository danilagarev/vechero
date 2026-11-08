import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partybox_mobile/src/app.dart';
import 'package:partybox_mobile/src/design/night_theme.dart';
import 'package:partybox_mobile/src/spy/local_session_adapter.dart';
import 'package:partybox_mobile/src/spy/spy_game_screen.dart';
import 'package:partybox_mobile/src/storage/spy_setup.dart';
import 'support/local_game_flow.dart';

class TestStore implements SpySetupStore {
  String? raw;
  bool failRead = false;
  bool failWrite = false;
  bool failClear = false;
  int writes = 0;
  Completer<void>? pendingWrite;
  @override
  Future<SetupRestore> load() async {
    if (failRead) throw StateError('Read failed');
    return SetupRestore.decode(raw);
  }

  @override
  Future<void> save(SpySetup setup) async {
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
    if (failWrite) throw StateError('Write failed');
    raw = jsonEncode(setup.toJson());
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('Clear failed');
    raw = null;
  }
}

SpySetup saved({int count = 6}) => SpySetup(
  names: List.generate(count, (i) => 'Игрок-$i'),
  discussionMinutes: 9,
  packId: 'test',
);
Widget screen(TestStore store) => MaterialApp(
  theme: nightTheme(),
  home: SpyGameScreen(
    adapter: LocalSessionAdapter(
      pack: SpyPack(
        id: 'test',
        version: 1,
        title: 'Тест',
        locations: ['Музей'],
      ),
      random: Random(15),
    ),
    setupStore: store,
  ),
);

void main() {
  testWidgets('restores setup and clears names, player count and time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = TestStore()..raw = jsonEncode(saved().toJson());
    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('player-name-0')))
          .controller!
          .text,
      'Игрок-0',
    );
    expect(find.byKey(const ValueKey('player-name-5')), findsOneWidget);
    await tapVisible(tester, find.text('К настройкам'));
    expect(find.text('9'), findsOneWidget);
    await tapVisible(tester, find.text('Изменить имена'));
    await tapVisible(tester, find.text('Очистить сохранённые данные'));
    expect(store.raw, isNull);
    expect(find.text('4'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-name-5')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('player-name-0')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'start is deduplicated while saving and restores only setup after restart',
    (tester) async {
      final store = TestStore()
        ..raw = jsonEncode(saved(count: 4).toJson())
        ..pendingWrite = Completer<void>();
      await tester.pumpWidget(screen(store));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('К настройкам'));
      final start = find.text('Раздать роли');
      await showWidget(tester, start);
      final point = tester.getCenter(start);
      await tester.tapAt(point);
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(store.writes, 1);
      expect(find.text('Готовим партию…'), findsOneWidget);
      store.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Карточка 1 из 4'), findsOneWidget);
      expect(jsonDecode(store.raw!).keys.toSet(), SpySetup.fields);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(screen(store));
      await tester.pumpAndSettle();
      expect(find.text('Кто играет?'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('player-name-0')))
            .controller!
            .text,
        'Игрок-0',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final mode in ['corrupt', 'future', 'read-error']) {
    testWidgets('$mode falls back to playable preparation', (tester) async {
      final store = TestStore()
        ..raw = mode == 'future' ? '{"schemaVersion":99}' : '{bad'
        ..failRead = mode == 'read-error';
      await tester.pumpWidget(screen(store));
      await tester.pumpAndSettle();
      expect(find.text('Кто играет?'), findsOneWidget);
      expect(find.byKey(const ValueKey('player-name-3')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('unavailable saved pack keeps names and uses the current pack', (
    tester,
  ) async {
    final store = TestStore()
      ..raw = jsonEncode({
        ...saved(count: 4).toJson(),
        'packId': 'removed-pack',
      });
    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();
    expect(find.textContaining('Прежний набор недоступен'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('player-name-0')))
          .controller!
          .text,
      'Игрок-0',
    );
    await tapVisible(tester, find.text('К настройкам'));
    expect(find.text('Тест'), findsOneWidget);
    await tapVisible(tester, find.text('Раздать роли'));
    expect(jsonDecode(store.raw!)['packId'], 'test');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('write failure allows a game and explains lost persistence', (
    tester,
  ) async {
    final store = TestStore()
      ..raw = jsonEncode(saved(count: 4).toJson())
      ..failWrite = true;
    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('К настройкам'));
    await tapVisible(tester, find.text('Раздать роли'));
    expect(find.text('Карточка 1 из 4'), findsOneWidget);
    expect(find.textContaining('настройки не сохранились'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clear failure preserves data and remains retryable', (
    tester,
  ) async {
    final store = TestStore()
      ..raw = jsonEncode(saved(count: 4).toJson())
      ..failClear = true;
    await tester.pumpWidget(screen(store));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Очистить сохранённые данные'));
    expect(store.raw, isNotNull);
    expect(find.textContaining('Не удалось удалить'), findsOneWidget);
    store.failClear = false;
    await tapVisible(tester, find.text('Очистить сохранённые данные'));
    expect(store.raw, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('production app routes carry setup storage to the game', (
    tester,
  ) async {
    final store = TestStore()
      ..raw = jsonEncode(
        SpySetup(
          names: ['Анна', 'Борис', 'Вера', 'Глеб'],
          discussionMinutes: 7,
          packId: 'spy-ru-base',
        ).toJson(),
      );
    await tester.pumpWidget(PartyBoxApp(setupStore: store));
    await tapVisible(tester, find.text('Как играть'));
    await tapVisible(tester, find.text('Собрать компанию'), loadsContent: true);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('player-name-0')))
          .controller!
          .text,
      'Анна',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'leaving while a write is pending does not start a disposed game',
    (tester) async {
      final store = TestStore()
        ..raw = jsonEncode(saved(count: 4).toJson())
        ..pendingWrite = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: nightTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => SpyGameScreen(
                      adapter: LocalSessionAdapter(
                        pack: SpyPack(
                          id: 'test',
                          version: 1,
                          title: 'Тест',
                          locations: ['Музей'],
                        ),
                      ),
                      setupStore: store,
                    ),
                  ),
                ),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Открыть'));
      await tapVisible(tester, find.text('К настройкам'));
      await tapVisible(tester, find.text('Раздать роли'));
      await goBack(tester);
      store.pendingWrite!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Открыть'), findsOneWidget);
      expect(find.text('Карточка 1 из 4'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
