import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/storage/preferences_spy_setup_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PartyBoxApp(setupStore: PreferencesSpySetupStore()));
}
