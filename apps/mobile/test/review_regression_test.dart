import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partybox_mobile/src/design/night_components.dart';
import 'package:partybox_mobile/src/design/night_theme.dart';
import 'package:partybox_mobile/src/spy/local_session_adapter.dart';
import 'package:partybox_mobile/src/spy/spy_game_screen.dart';
import 'support/design_fonts.dart';
import 'support/local_game_flow.dart';

void main() {
  for (final useNight in [false, true]) {
    testWidgets('reduced iOS route preserves edge gesture night=$useNight', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var returned = false;
      try {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await tester.pumpWidget(
          MaterialApp(
            theme: nightTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    useNight
                        ? NightRoute(
                            builder: (_) => const Scaffold(body: Text('child')),
                          )
                        : MaterialPageRoute(
                            builder: (_) => const Scaffold(body: Text('child')),
                          ),
                  ),
                  child: const Text('root'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('root'));
        await tester.pumpAndSettle();
        await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
        await tester.pumpAndSettle();
        returned = find.text('root').evaluate().isNotEmpty;
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        debugDefaultTargetPlatformOverride = null;
      }
      expect(
        returned,
        true,
        reason: 'The edge gesture should still return in reduced motion',
      );
    });
  }

  for (final location in [
    'Музей',
    'Туристический лагерь',
    'Космическая станция',
  ]) {
    testWidgets('physical double tap leaves next role hidden $location', (
      tester,
    ) async {
      await loadDesignFonts(tester);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: nightTheme(),
          home: SpyGameScreen(
            adapter: LocalSessionAdapter(
              pack: SpyPack(
                id: 'probe',
                version: 1,
                title: 'Probe',
                locations: [location],
              ),
              random: Random(15),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        final field = find.byKey(ValueKey('player-name-$i'));
        await showWidget(tester, field);
        await tester.enterText(field, ['Анна', 'Борис', 'Вера', 'Глеб'][i]);
      }
      await tapVisible(tester, find.text('К настройкам'));
      await tapVisible(tester, find.text('Раздать роли'));
      await tapVisible(tester, find.text('Показать мою роль'));
      await showWidget(tester, find.byKey(const ValueKey('handoff-role')));
      final point = tester.getCenter(
        find.byKey(const ValueKey('handoff-role')),
      );
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(
        find.byType(Card),
        findsNothing,
        reason: 'A second physical tap must not reveal the next role',
      );
      expect(find.text('Карточка 2 из 4'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tapVisible(tester, find.text('Показать мою роль'));
      expect(find.byType(Card), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
