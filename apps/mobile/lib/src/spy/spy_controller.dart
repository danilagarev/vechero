import 'package:flutter/foundation.dart';
import 'package:partybox_game_core/partybox_game_core.dart';

import 'local_session_adapter.dart';

/// UI session state. Rules and transitions remain in game_core.
final class SpyController extends ChangeNotifier {
  SpyController({required this.adapter, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalSessionAdapter adapter;
  final DateTime Function() _now;
  SpySession? _session;
  bool _revealed = false;
  bool _foreground = true;

  SpyPhase? get phase => _session?.phase;
  List<Player> get players => _session?.players ?? const [];
  int get distributedCount => _session?.distributedCount ?? 0;
  Player? get currentPlayer =>
      phase == SpyPhase.distribution ? players[distributedCount] : null;
  SpyCard? get visibleCard =>
      _revealed && _foreground ? _session?.cardFor(currentPlayer!.id) : null;
  Map<String, Object?>? get result =>
      _session?.publicView()['result'] as Map<String, Object?>?;
  int get remainingSeconds {
    final deadline = _session?.deadline;
    if (deadline == null || phase != SpyPhase.discussion) return 0;
    final milliseconds = deadline.difference(_now().toUtc()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  void start(List<String> names, Duration duration) {
    if (_session != null) return;
    _session = adapter.create([
      for (var i = 0; i < names.length; i++)
        Player(id: 'p$i', name: names[i].trim()),
    ], duration);
    notifyListeners();
  }

  void reveal(String playerId) {
    if (!_foreground || currentPlayer?.id != playerId || _revealed) return;
    _revealed = true;
    notifyListeners();
  }

  void handoff(String playerId) {
    if (!_foreground || !_revealed || currentPlayer?.id != playerId) return;
    _revealed = false;
    _session = _session!.acknowledgeRole(playerId, now: _now());
    notifyListeners();
  }

  void conceal() {
    _revealed = false;
    notifyListeners();
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _revealed = false;
    tick();
  }

  void tick() {
    _session = _session?.advanceTime(_now());
    notifyListeners();
  }

  void startVoting() {
    if (phase != SpyPhase.discussion) return;
    _session = _session!.startVoting();
    notifyListeners();
  }

  void accuse(String playerId) {
    if (phase != SpyPhase.voting) return;
    _session = _session!.accuse(playerId);
    notifyListeners();
  }

  void replay() {
    if (phase != SpyPhase.results) return;
    _session = adapter.create(players, _session!.duration);
    _revealed = false;
    notifyListeners();
  }
}
