import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadDesignFonts(WidgetTester tester) => tester.runAsync(() async {
  await (FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Manrope-ExtraBold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
});
