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

/// Per-role daily chore defaults (kind 31500).
///
/// A set is either the role's [base][] set (addressable by role id alone,
/// what daily generation uses) or a named variant (addressable by
/// `role:name`). Activating a variant means writing its chores as the base.
class RoleDefaultSet {
  const RoleDefaultSet({required this.role, required this.chores, this.name});

  final FarmRole role;
  final List<ChoreDefault> chores;

  /// Variant name; null for the role's base (active) set.
  final String? name;

  /// True when this set is the role's active base set.
  bool get isBase => name == null;

  /// Canonical addressable id (NIP-01 `d` tag): `role` or `role:name`.
  String get dTag => isBase ? role.id : '${role.id}:$name';

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
      'role': role.id,
      if (!isBase) 'name': name,
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

  /// Parses a kind 31500 event back into a default set. The role comes
  /// from the content (`role`); older events without it fall back to the
  /// d tag.
  factory RoleDefaultSet.fromNostrEvent(NostrEvent event) {
    if (event.kind != roleDefaultSetKind) {
      throw FormatException(
        'expected kind $roleDefaultSetKind, got ${event.kind}',
      );
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
    final roleId = decoded['role'] as String?;
    final role = roleId == null
        ? _roleFromDTag(event)
        : FarmRole.fromIdOrNull(roleId);
    if (role == null) {
      throw const FormatException('default set needs a valid role');
    }
    final name = decoded['name'] as String?;
    return RoleDefaultSet(
      role: role,
      chores: choresJson
          .map((c) => ChoreDefault.fromJson(c as Map<String, dynamic>))
          .toList(),
      name: name,
    );
  }

  static FarmRole? _roleFromDTag(NostrEvent event) {
    final dTag = event.tags
        .where((t) => t.isNotEmpty && t.first == 'd')
        .map((t) => t[1])
        .firstOrNull;
    if (dTag == null) {
      throw const FormatException('role default set needs a d tag');
    }
    return FarmRole.fromIdOrNull(dTag);
  }
}
