import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partybox_game_content/partybox_game_content.dart';
import 'package:partybox_mobile/src/app.dart';

void main() {
  testWidgets('catalog opens rules and can return', (tester) async {
    await tester.pumpWidget(const PartyBoxApp());
    expect(find.text('Шпион'), findsOneWidget);
    await tester.tap(find.text('Как играть'));
    await tester.pumpAndSettle();
    expect(find.text('Один из вас не в курсе.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Как играть'), findsOneWidget);
  });

  testWidgets('small screen and large text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const PartyBoxApp());
    await tester.scrollUntilVisible(find.text('Как играть'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Как играть'));
    await tester.pumpAndSettle();
    expect(find.text('Один из вас не в курсе.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starter location pack is included in the asset bundle', (
    tester,
  ) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(manifest.listAssets(), contains(spyBasePackAsset));
    final content = await rootBundle.loadString(spyBasePackAsset);
    expect(content, contains('spy-ru-base'));
  });
}
