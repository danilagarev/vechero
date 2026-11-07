import 'dart:math';

enum SpyPhase { distribution, discussion, voting, results }

enum SpyRole { spy, civilian }

enum SpyWinner { spy, civilians }

final class Player {
  const Player({required this.id, required this.name});

  final String id;
  final String name;
}

final class SpyCard {
  const SpyCard({required this.role, this.location});

  final SpyRole role;
  final String? location;
}

/// A local session. Never serialize this object for multiplayer clients.
/// Send only a public projection and the authenticated player's personal card.
final class SpySession {
  SpySession._({
    required this.players,
    required String location,
    required int spyIndex,
    required this.duration,
    required this.phase,
    required this.distributedCount,
    this.deadline,
    this.suspectId,
  }) : _location = location,
       _spyIndex = spyIndex;

  factory SpySession.create({
    required List<Player> players,
    required String location,
    required Random random,
    Duration duration = const Duration(minutes: 5),
  }) {
    if (players.length < 4 || players.length > 12) {
      throw ArgumentError('Spy requires 4–12 players');
    }
    if (players.any((p) => p.id.trim().isEmpty || p.name.trim().isEmpty)) {
      throw ArgumentError('Player IDs and names must not be blank');
    }
    if (players.map((p) => p.id).toSet().length != players.length) {
      throw ArgumentError('Player IDs must be unique');
    }
    if (location.trim().isEmpty) {
      throw ArgumentError('Location must not be blank');
    }
    if (duration < const Duration(minutes: 3) ||
        duration > const Duration(minutes: 15)) {
      throw ArgumentError('Discussion must last 3–15 minutes');
    }
    return SpySession._(
      players: List.unmodifiable(players),
      location: location.trim(),
      spyIndex: random.nextInt(players.length),
      duration: duration,
      phase: SpyPhase.distribution,
      distributedCount: 0,
    );
  }

  final List<Player> players;
  final String _location;
  final int _spyIndex;
  final Duration duration;
  final SpyPhase phase;
  final int distributedCount;
  final DateTime? deadline;
  final String? suspectId;

  String? get nextPlayerId =>
      phase == SpyPhase.distribution ? players[distributedCount].id : null;

  SpyCard cardFor(String playerId) {
    final index = players.indexWhere((p) => p.id == playerId);
    if (index == -1) throw ArgumentError('Unknown player');
    return index == _spyIndex
        ? const SpyCard(role: SpyRole.spy)
        : SpyCard(role: SpyRole.civilian, location: _location);
  }

  /// The UI must hide the card before acknowledging the handoff.
  SpySession acknowledgeRole(String playerId, {required DateTime now}) {
    if (phase != SpyPhase.distribution || playerId != nextPlayerId) {
      throw StateError('Only the next player can acknowledge distribution');
    }
    final count = distributedCount + 1;
    final done = count == players.length;
    return SpySession._(
      players: players,
      location: _location,
      spyIndex: _spyIndex,
      duration: duration,
      phase: done ? SpyPhase.discussion : SpyPhase.distribution,
      distributedCount: count,
      deadline: done ? now.toUtc().add(duration) : null,
    );
  }

  /// Used for an explicit early end by the group/host.
  SpySession startVoting() {
    if (phase != SpyPhase.discussion) {
      throw StateError('Voting can only follow discussion');
    }
    return _withPhase(SpyPhase.voting);
  }

  /// Clock ticks have no effect outside discussion or before its deadline.
  SpySession advanceTime(DateTime now) {
    if (phase == SpyPhase.discussion && !now.toUtc().isBefore(deadline!)) {
      return startVoting();
    }
    return this;
  }

  SpySession accuse(String playerId) {
    if (phase != SpyPhase.voting) {
      throw StateError('An accusation requires voting');
    }
    if (!players.any((p) => p.id == playerId)) {
      throw ArgumentError('Unknown suspect');
    }
    return _withPhase(SpyPhase.results, suspectId: playerId);
  }

  SpyWinner? get winner {
    if (phase != SpyPhase.results) return null;
    return suspectId == players[_spyIndex].id
        ? SpyWinner.civilians
        : SpyWinner.spy;
  }

  /// An allowlist projection: secrets appear only in the terminal result.
  Map<String, Object?> publicView() => {
    'gameId': 'spy',
    'phase': phase.name,
    'players': [
      for (final player in players) {'id': player.id, 'name': player.name},
    ],
    'deadline': deadline?.toIso8601String(),
    if (phase == SpyPhase.results)
      'result': {
        'spyId': players[_spyIndex].id,
        'location': _location,
        'suspectId': suspectId,
        'winner': winner!.name,
      },
  };

  SpySession _withPhase(SpyPhase next, {String? suspectId}) => SpySession._(
    players: players,
    location: _location,
    spyIndex: _spyIndex,
    duration: duration,
    phase: next,
    distributedCount: distributedCount,
    deadline: deadline,
    suspectId: suspectId,
  );
}
