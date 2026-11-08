import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:partybox_game_core/partybox_game_core.dart';
import 'package:partybox_mobile/src/spy/local_session_adapter.dart';
import 'package:partybox_mobile/src/spy/spy_controller.dart';

void main() {
  late DateTime now;
  late SpyController controller;

  setUp(() {
    now = DateTime.utc(2026, 11, 8);
    controller = SpyController(
      adapter: LocalSessionAdapter(
        pack: SpyPack(
          id: 'test',
          version: 1,
          title: 'Тест',
          locations: ['Музей'],
        ),
        random: Random(42),
      ),
      now: () => now,
    );
  });
  tearDown(() => controller.dispose());

  void distribute() {
    controller.start([
      'Анна',
      'Борис',
      'Вера',
      'Глеб',
    ], const Duration(minutes: 3));
    for (var i = 0; i < 4; i++) {
      controller.reveal('p$i');
      controller.handoff('p$i');
    }
  }

  test('deadline starts after distribution and expires across background', () {
    distribute();
    expect(controller.remainingSeconds, 180);
    now = now.add(const Duration(seconds: 61));
    controller.setForeground(false);
    expect(controller.remainingSeconds, 119);
    now = now.add(const Duration(hours: 1));
    controller.setForeground(true);
    expect(controller.phase, SpyPhase.voting);
    expect(controller.remainingSeconds, 0);
    expect(controller.result, isNull);
    controller.accuse('p0');
    final result = controller.result;
    controller.accuse('p1');
    expect(controller.result, result);
    controller.replay();
    expect(controller.players.map((p) => p.name), [
      'Анна',
      'Борис',
      'Вера',
      'Глеб',
    ]);
    expect(controller.phase, SpyPhase.distribution);
    expect(controller.visibleCard, isNull);
    expect(controller.result, isNull);
    for (var i = 0; i < 4; i++) {
      controller.reveal('p$i');
      controller.handoff('p$i');
    }
    expect(controller.remainingSeconds, 180);
  });

  test(
    'stale callbacks and background cannot reveal or advance another card',
    () {
      controller.start(['A', 'B', 'C', 'D'], const Duration(minutes: 5));
      controller.start(['E', 'F', 'G', 'H'], const Duration(minutes: 5));
      controller.handoff('p0');
      expect(controller.distributedCount, 0);
      controller.reveal('p1');
      expect(controller.visibleCard, isNull);
      controller.reveal('p0');
      expect(controller.visibleCard, isNotNull);
      controller.setForeground(false);
      controller.reveal('p0');
      controller.handoff('p0');
      expect(controller.visibleCard, isNull);
      expect(controller.distributedCount, 0);
      controller.setForeground(true);
      expect(controller.visibleCard, isNull);
      controller.reveal('p0');
      controller.handoff('p0');
      controller.handoff('p0');
      controller.reveal('p0');
      expect(controller.currentPlayer!.id, 'p1');
      expect(controller.visibleCard, isNull);
    },
  );
}
