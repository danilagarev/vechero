import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:partybox_game_content/partybox_game_content.dart';
import 'package:partybox_game_core/partybox_game_core.dart';

/// Immutable bundled content. A running controller keeps this exact pack version.
final class SpyPack {
  SpyPack({
    required this.id,
    required this.version,
    required this.title,
    required List<String> locations,
  }) : locations = List.unmodifiable(locations) {
    if (locations.isEmpty || locations.any((label) => label.trim().isEmpty)) {
      throw const FormatException('Empty locations');
    }
  }

  final String id;
  final int version;
  final String title;
  final List<String> locations;

  static Future<SpyPack> load() async {
    final json =
        jsonDecode(await rootBundle.loadString(spyBasePackAsset))
            as Map<String, dynamic>;
    if (json['schemaVersion'] != 1 ||
        json['gameId'] != 'spy' ||
        json['locale'] != 'ru') {
      throw const FormatException('Unsupported pack');
    }
    return SpyPack(
      id: json['id'] as String,
      version: json['version'] as int,
      title: json['title'] as String,
      locations: [
        for (final item in json['items'] as List<dynamic>)
          (item as Map<String, dynamic>)['label'] as String,
      ],
    );
  }
}

final class LocalSessionAdapter {
  LocalSessionAdapter({required this.pack, Random? random})
    : _random = random ?? Random();

  final SpyPack pack;
  final Random _random;

  SpySession create(List<Player> players, Duration duration) =>
      SpySession.create(
        players: players,
        location: pack.locations[_random.nextInt(pack.locations.length)],
        random: _random,
        duration: duration,
      );
}
