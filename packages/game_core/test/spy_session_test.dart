import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:partybox_game_core/partybox_game_core.dart';
import 'package:test/test.dart';

final players = List.generate(4, (i) => Player(id: 'p$i', name: 'Игрок $i'));
final now = DateTime.utc(2026, 11, 7, 18);

SpySession create({int seed = 42}) => SpySession.create(
  players: players,
  location: 'Библиотека',
  random: Random(seed),
);

SpySession distribute(SpySession session) {
  for (final player in players) {
    session = session.acknowledgeRole(player.id, now: now);
  }
  return session;
}

void main() {
  test('exactly one spy and one common location across random seeds', () {
    for (var seed = 0; seed < 50; seed++) {
      final session = create(seed: seed);
      final cards = players.map((p) => session.cardFor(p.id)).toList();
      expect(cards.where((c) => c.role == SpyRole.spy), hasLength(1));
      expect(cards.singleWhere((c) => c.role == SpyRole.spy).location, isNull);
      expect(
        cards.where((c) => c.role == SpyRole.civilian).map((c) => c.location),
        everyElement('Библиотека'),
      );
    }
  });

  test(
    'distribution is ordered and immutable; clock starts after last handoff',
    () {
      final initial = create();
      expect(() => initial.acknowledgeRole('p1', now: now), throwsStateError);
      final next = initial.acknowledgeRole('p0', now: now);
      expect(initial.nextPlayerId, 'p0');
      expect(next.nextPlayerId, 'p1');
      expect(next.deadline, isNull);
      expect(() => next.acknowledgeRole('p0', now: now), throwsStateError);
      final ready = distribute(initial);
      expect(ready.phase, SpyPhase.discussion);
      expect(ready.nextPlayerId, isNull);
      expect(ready.deadline, now.add(const Duration(minutes: 5)));
      expect(() => ready.acknowledgeRole('p0', now: now), throwsStateError);
    },
  );

  test('deadline handles a long absence without timer ticks', () {
    final session = distribute(create());
    expect(session.advanceTime(now).phase, SpyPhase.discussion);
    expect(session.advanceTime(session.deadline!).phase, SpyPhase.voting);
    expect(
      session.advanceTime(now.add(const Duration(hours: 1))).phase,
      SpyPhase.voting,
    );
  });

  test('both victory paths and illegal actions', () {
    final initial = create();
    expect(() => initial.startVoting(), throwsStateError);
    expect(() => initial.accuse('p0'), throwsStateError);
    expect(() => initial.cardFor('outsider'), throwsArgumentError);
    final voting = distribute(initial).startVoting();
    expect(() => voting.accuse('outsider'), throwsArgumentError);
    final spy = players.singleWhere(
      (p) => initial.cardFor(p.id).role == SpyRole.spy,
    );
    final civilian = players.firstWhere((p) => p.id != spy.id);
    expect(voting.accuse(spy.id).winner, SpyWinner.civilians);
    expect(voting.accuse(civilian.id).winner, SpyWinner.spy);
    expect(() => voting.accuse(spy.id).accuse(spy.id), throwsStateError);
  });

  test('public state is an allowlist until the final reveal', () {
    final session = create();
    final discussion = distribute(session);
    final voting = discussion.startVoting();
    for (final state in [session, discussion, voting]) {
      expect(
        state.publicView().keys,
        unorderedEquals(['gameId', 'phase', 'players', 'deadline']),
      );
      expect(jsonEncode(state.publicView()), isNot(contains('Библиотека')));
      expect(state.winner, isNull);
    }
    final result = voting.accuse('p0').publicView()['result'];
    expect(result, isA<Map<String, Object?>>());
  });

  test('invalid configurations are rejected and roster cannot be mutated', () {
    for (final count in [0, 3, 13]) {
      expect(
        () => SpySession.create(
          players: List.generate(count, (i) => Player(id: '$i', name: '$i')),
          location: 'Музей',
          random: Random(1),
        ),
        throwsArgumentError,
      );
    }
    for (final duration in [
      const Duration(seconds: 179),
      const Duration(minutes: 16),
    ]) {
      expect(
        () => SpySession.create(
          players: players,
          location: 'Музей',
          random: Random(1),
          duration: duration,
        ),
        throwsArgumentError,
      );
    }
    for (final roster in [
      [...players.take(3), players.first],
      [...players.take(3), const Player(id: 'p3', name: ' ')],
    ]) {
      expect(
        () => SpySession.create(
          players: roster,
          location: 'Музей',
          random: Random(1),
        ),
        throwsArgumentError,
      );
    }
    expect(() => create().players.clear(), throwsUnsupportedError);
  });

  test('bundled JSON content can supply a round location', () {
    final pack =
        jsonDecode(
              File('../game-content/packs/spy-ru-base.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final items = pack['items'] as List<dynamic>;
    final first = items.first as Map<String, dynamic>;
    final session = SpySession.create(
      players: players,
      location: first['label'] as String,
      random: Random(1),
    );
    expect(session.phase, SpyPhase.distribution);
  });
}
