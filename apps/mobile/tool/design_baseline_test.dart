// Opt-in PB-015 source captures, not visual regression baselines.
// flutter test tool/design_baseline_test.dart --update-goldens
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partybox_mobile/src/app.dart';
import 'package:partybox_mobile/src/spy/local_session_adapter.dart';
import 'package:partybox_mobile/src/spy/spy_game_screen.dart';

import '../test/support/local_game_flow.dart';

void main() {
  testWidgets('capture PB-010 before visual redesign', (tester) async {
    // Widget tests use Ahem by default. Supply a local Cyrillic font explicitly.
    final fontPath = Platform.environment['PB_DESIGN_FONT'];
    if (fontPath == null) {
      throw StateError('Set PB_DESIGN_FONT to a local Cyrillic TTF font.');
    }
    await tester.runAsync(() async {
      final bytes = await File(fontPath).readAsBytes();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: boundary, child: const PartyBoxApp()),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile('../../../docs/design/pb-015/before-$name.png'),
      );
    }

    await capture('catalog');
    final theme = Theme.of(tester.element(find.byType(CatalogScreen)));
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: theme,
          home: SpyGameScreen(
            adapter: LocalSessionAdapter(
              pack: SpyPack(
                id: 'design-fixture',
                version: 1,
                title: 'Тестовый набор',
                locations: ['Музей'],
              ),
              random: Random(15),
            ),
            now: () => DateTime.utc(2026, 11, 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      final field = find.byKey(ValueKey('player-name-$i'));
      await showWidget(tester, field);
      await tester.enterText(field, ['Александра', 'Борис', 'Вера', 'Глеб'][i]);
    }
    await tapVisible(tester, find.text('К настройкам'));
    await tapVisible(tester, find.text('Раздать роли'));
    await capture('handoff');
    await tapVisible(tester, find.text('Показать мою роль'));
    await capture('role');
    await tapVisible(tester, find.text('Скрыть и передать'));
    for (var i = 1; i < 4; i++) {
      await tapVisible(tester, find.text('Показать мою роль'));
      await tapVisible(tester, find.text('Скрыть и передать'));
    }
    await tapVisible(tester, find.text('Завершить обсуждение'));
    await tapVisible(tester, find.text('Александра'));
    await tapVisible(tester, find.text('Подтвердить и раскрыть'));
    await capture('result');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
