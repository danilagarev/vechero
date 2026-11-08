import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'spy_setup.dart';

final class PreferencesSpySetupStore implements SpySetupStore {
  PreferencesSpySetupStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  static const key = 'vechero.spy.setup';
  final SharedPreferencesAsync _preferences;

  Future<void> _pending = Future<void>.value();

  // Preserve user action order, including when the initiating route was closed.
  Future<void> _write(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<SetupRestore> load() async {
    await _pending;
    return SetupRestore.decode(await _preferences.getString(key));
  }

  @override
  Future<void> save(SpySetup setup) =>
      _write(() => _preferences.setString(key, jsonEncode(setup.toJson())));
  @override
  Future<void> clear() => _write(() => _preferences.remove(key));
}
