import 'dart:convert';

import 'roles.dart';
import '../nostr/nostr_event.dart';

/// Kind for a per-role daily chore default set.
const int roleDefaultSetKind = 31500;

/// One default chore within a role's default set.
class ChoreDefault {
  const ChoreDefault({
    required this.title,
    required this.weekdays,
    this.assigneeHint,
  });

  final String title;

  /// 1=Monday .. 6=Saturday. Sundays are rest days at the farm.
  final List<int> weekdays;
  final String? assigneeHint;

  bool runsOnWeekday(DateTime date) => weekdays.contains(date.weekday);

  ChoreDefault copyWith({String? assigneeHint}) => ChoreDefault(
    title: title,
    weekdays: weekdays,
    assigneeHint: assigneeHint ?? this.assigneeHint,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'weekdays': weekdays,
    if (assigneeHint != null) 'assigneeHint': assigneeHint,
  };

  factory ChoreDefault.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final weekdays = json['weekdays'];
    if (title is! String || title.isEmpty) {
      throw const FormatException('chore default needs a title');
    }
    if (weekdays is! List) {
      throw const FormatException('chore default needs weekdays');
    }
    final parsed = weekdays.map((w) => w as int).toList();
    if (parsed.any((w) => w < 1 || w > 6)) {
      throw const FormatException(
        'weekdays must be 1=Monday..6=Saturday (Sunday rest)',
      );
    }
    return ChoreDefault(
      title: title,
      weekdays: parsed,
      assigneeHint: json['assigneeHint'] as String?,
    );
  }
}

/// Per-role daily chore defaults (kind 31500, addressable by role).
class RoleDefaultSet {
  const RoleDefaultSet({required this.role, required this.chores});

  final FarmRole role;
  final List<ChoreDefault> chores;

  /// Canonical addressable id: the role id (NIP-01 `d` tag).
  String get dTag => role.id;

  /// Serializes this set as a signed-ready kind 31500 event. The caller
  /// signs and stores the result.
  NostrEvent toNostrEvent({
    required String pubKey,
    required int createdAt,
    String? farmPubkey,
    List<List<String>> extraTags = const [],
  }) {
    final content = jsonEncode({
      'chores': chores.map((c) => c.toJson()).toList(),
    });
    return NostrEvent(
      pubKey: pubKey,
      createdAt: createdAt,
      kind: roleDefaultSetKind,
      tags: [
        ['d', dTag],
        if (farmPubkey != null) ['farm', farmPubkey],
        ...extraTags,
      ],
      content: content,
    );
  }

  /// Parses a kind 31500 event back into a default set.
  factory RoleDefaultSet.fromNostrEvent(NostrEvent event) {
    if (event.kind != roleDefaultSetKind) {
      throw FormatException(
        'expected kind $roleDefaultSetKind, got ${event.kind}',
      );
    }
    final dTag = event.tags
        .where((t) => t.isNotEmpty && t.first == 'd')
        .map((t) => t[1])
        .firstOrNull;
    if (dTag == null) {
      throw const FormatException('role default set needs a d tag');
    }
    final role = FarmRole.fromIdOrNull(dTag);
    if (role == null) {
      throw FormatException('unknown role in d tag: $dTag');
    }
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(event.content) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('malformed default set content: $e');
    }
    final choresJson = decoded['chores'];
    if (choresJson is! List) {
      throw const FormatException('default set needs a chores list');
    }
    return RoleDefaultSet(
      role: role,
      chores: choresJson
          .map((c) => ChoreDefault.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
