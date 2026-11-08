import 'dart:convert';

/// Public preparation only. Never include a session, role, location or seed here.
final class SpySetup {
  factory SpySetup({
    required List<String> names,
    required int discussionMinutes,
    required String packId,
  }) {
    final trimmed = names.map((name) => name.trim()).toList(growable: false);
    if (trimmed.length < 4 ||
        trimmed.length > 12 ||
        trimmed.any((name) => name.isEmpty) ||
        discussionMinutes < 3 ||
        discussionMinutes > 15 ||
        packId.trim().isEmpty) {
      throw const FormatException('Invalid spy setup');
    }
    return SpySetup._(List.unmodifiable(trimmed), discussionMinutes, packId);
  }

  const SpySetup._(this.names, this.discussionMinutes, this.packId);
  final List<String> names;
  final int discussionMinutes;
  final String packId;

  static const fields = {
    'schemaVersion',
    'gameId',
    'names',
    'discussionMinutes',
    'packId',
  };

  factory SpySetup.fromJson(Map<String, dynamic> json) {
    if (json.length != fields.length ||
        !json.keys.every(fields.contains) ||
        json['schemaVersion'] is! int ||
        json['schemaVersion'] != 1 ||
        json['gameId'] != 'spy' ||
        json['names'] is! List ||
        !(json['names'] as List).every((name) => name is String) ||
        json['discussionMinutes'] is! int ||
        json['packId'] is! String) {
      throw const FormatException('Invalid spy setup format');
    }
    return SpySetup(
      names: (json['names'] as List).cast<String>(),
      discussionMinutes: json['discussionMinutes'] as int,
      packId: json['packId'] as String,
    );
  }

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'gameId': 'spy',
    'names': names,
    'discussionMinutes': discussionMinutes,
    'packId': packId,
  };
}

enum SetupRestoreStatus { empty, restored, invalid, unsupportedVersion }

final class SetupRestore {
  const SetupRestore(this.status, [this.setup]);
  final SetupRestoreStatus status;
  final SpySetup? setup;

  static SetupRestore decode(String? raw) {
    if (raw == null) return const SetupRestore(SetupRestoreStatus.empty);
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return const SetupRestore(SetupRestoreStatus.invalid);
      }
      if (json['schemaVersion'] is int && json['schemaVersion'] != 1) {
        return const SetupRestore(SetupRestoreStatus.unsupportedVersion);
      }
      return SetupRestore(SetupRestoreStatus.restored, SpySetup.fromJson(json));
    } on FormatException {
      return const SetupRestore(SetupRestoreStatus.invalid);
    }
  }
}

abstract interface class SpySetupStore {
  Future<SetupRestore> load();
  Future<void> save(SpySetup setup);
  Future<void> clear();
}
