import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:partybox_mobile/src/storage/spy_setup.dart';
import 'package:partybox_mobile/src/storage/preferences_spy_setup_store.dart';

base class DelayedPreferences extends InMemorySharedPreferencesAsync {
  DelayedPreferences() : super.empty();
  Completer<void>? gate;
  bool failNext = false;
  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    if (gate != null) {
      final waiting = gate!;
      gate = null;
      await waiting.future;
    }
    if (failNext) {
      failNext = false;
      throw StateError('Write failed');
    }
    return super.setString(key, value, options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> example;
  setUp(() async {
    example =
        jsonDecode(await File('test/fixtures/spy_setup_v1.json').readAsString())
            as Map<String, dynamic>;
  });

  test('version 1 fixture and immutable normalized names', () {
    final setup = SpySetup.fromJson(example);
    expect(setup.discussionMinutes, 7);
    expect(setup.names, ['Анна', 'Борис', 'Вера', 'Глеб']);
    expect(() => setup.names.add('Игрок'), throwsUnsupportedError);
    final names = [' Анна ', 'Анна', 'Вера', 'Глеб'];
    final copy = SpySetup(
      names: names,
      discussionMinutes: 3,
      packId: 'spy-ru-base',
    );
    names[0] = 'Изменено';
    expect(copy.names.first, 'Анна');
    expect(
      SpySetup(
        names: List.filled(12, 'Игрок'),
        discussionMinutes: 15,
        packId: 'base',
      ).names,
      hasLength(12),
    );
  });

  test('invalid fields, bounds and secret fields are rejected', () {
    final badRecords = [
      {...example, 'schemaVersion': 1.0},
      {...example, 'gameId': 'other'},
      {
        ...example,
        'names': ['A', 'B', 'C'],
      },
      {...example, 'names': List.filled(13, 'A')},
      {
        ...example,
        'names': ['A', 'B', 'C', ' '],
      },
      {
        ...example,
        'names': ['A', 'B', 'C', 1],
      },
      {...example, 'discussionMinutes': 2},
      {...example, 'discussionMinutes': 16},
      {...example, 'discussionMinutes': 7.0},
      {...example, 'packId': ''},
      {...example, 'packId': false},
      {...example, 'spyId': 'p1'},
      {...example, 'location': 'Музей'},
      {...example}..remove('names'),
    ];
    for (final record in badRecords) {
      expect(
        SetupRestore.decode(jsonEncode(record)).status,
        SetupRestoreStatus.invalid,
      );
    }
    expect(SpySetup.fromJson(example).toJson().keys.toSet(), SpySetup.fields);
  });

  test('empty, corrupt and future formats have explicit safe outcomes', () {
    expect(SetupRestore.decode(null).status, SetupRestoreStatus.empty);
    for (final raw in ['', 'null', '[]', '{broken']) {
      expect(SetupRestore.decode(raw).status, SetupRestoreStatus.invalid);
    }
    final future = SetupRestore.decode(
      jsonEncode({...example, 'schemaVersion': 2}),
    );
    expect(future.status, SetupRestoreStatus.unsupportedVersion);
    expect(future.setup, isNull);
  });

  test(
    'preferences adapter survives new instances and clears only its key',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
      final prefs = SharedPreferencesAsync();
      await prefs.setString('unrelated', 'keep');
      final writer = PreferencesSpySetupStore(preferences: prefs);
      await writer.save(SpySetup.fromJson(example));
      final reader = PreferencesSpySetupStore();
      expect((await reader.load()).setup!.toJson(), example);
      final raw =
          jsonDecode((await prefs.getString(PreferencesSpySetupStore.key))!)
              as Map;
      expect(raw.keys.toSet(), SpySetup.fields);
      await reader.clear();
      expect((await writer.load()).status, SetupRestoreStatus.empty);
      expect(await prefs.getString('unrelated'), 'keep');
    },
  );

  test(
    'clear follows pending write and a failed write does not poison the queue',
    () async {
      final previous = SharedPreferencesAsyncPlatform.instance;
      final backend = DelayedPreferences();
      SharedPreferencesAsyncPlatform.instance = backend;
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
      final store = PreferencesSpySetupStore();
      final pending = Completer<void>();
      backend.gate = pending;
      final write = store.save(SpySetup.fromJson(example));
      final clear = store.clear();
      pending.complete();
      await write;
      await clear;
      expect((await store.load()).status, SetupRestoreStatus.empty);
      backend.failNext = true;
      await expectLater(
        store.save(SpySetup.fromJson(example)),
        throwsStateError,
      );
      await store.save(SpySetup.fromJson(example));
      expect((await store.load()).setup!.toJson(), example);
    },
  );

  test('reading an unknown version preserves the original bytes', () async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    final raw = jsonEncode({...example, 'schemaVersion': 99});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          PreferencesSpySetupStore.key: raw,
        });
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    expect(
      (await PreferencesSpySetupStore().load()).status,
      SetupRestoreStatus.unsupportedVersion,
    );
    expect(
      await SharedPreferencesAsync().getString(PreferencesSpySetupStore.key),
      raw,
    );
  });
}
