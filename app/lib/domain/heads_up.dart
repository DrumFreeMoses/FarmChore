import 'dart:convert';

import 'roles.dart';
import '../nostr/nostr_event.dart';

/// Kind for a farm heads-up notice (weather, alerts, reminders, news).
const int headsUpKind = 31505;

/// Type of heads-up: casual news vs urgent alert.
enum HeadsUpType { news, alert }

/// A short farm notice (kind 31505). Scoped to the whole farm or to one
/// role group; authored by any member.
class HeadsUp {
  const HeadsUp({
    required this.text,
    required this.author,
    required this.createdAt,
    this.scope,
    this.type = HeadsUpType.news,
    this.escalationTag,
  });

  final String text;

  /// Pubkey of the member who wrote it.
  final String author;

  final int createdAt;

  /// Null = farm-wide; a role id = for that role's group.
  final FarmRole? scope;

  /// News (casual) or alert (urgent, gets a red treatment).
  final HeadsUpType type;

  /// Optional tag linking this heads-up to a chore escalation
  /// (e.g. "escalation|2026-08-05|milkers|milk-cows").
  /// Prevents duplicate escalation posts for the same chore.
  final String? escalationTag;

  /// Addressable id: author + creation time (unique per author per second).
  String get dTag => '$author-$createdAt';

  bool get isFarmWide => scope == null;
  bool get isAlert => type == HeadsUpType.alert;

  NostrEvent toNostrEvent({
    required String pubKey,
    required int createdAt,
    String? farmPubkey,
    List<List<String>> extraTags = const [],
  }) {
    return NostrEvent(
      pubKey: pubKey,
      createdAt: createdAt,
      kind: headsUpKind,
      tags: [
        ['d', dTag],
        if (scope != null) ['role', scope!.id],
        if (farmPubkey != null) ['farm', farmPubkey],
        if (escalationTag != null) ['escalation', escalationTag!],
        ...extraTags,
      ],
      content: jsonEncode({
        'text': text,
        if (type == HeadsUpType.alert) 'type': 'alert',
      }),
    );
  }

  factory HeadsUp.fromNostrEvent(NostrEvent event) {
    if (event.kind != headsUpKind) {
      throw FormatException('expected kind $headsUpKind, got ${event.kind}');
    }
    final dTag = event.tags
        .where((t) => t.isNotEmpty && t.first == 'd')
        .map((t) => t[1])
        .firstOrNull;
    if (dTag == null) {
      throw const FormatException('heads-up needs a d tag');
    }
    final decoded = jsonDecode(event.content) as Map<String, dynamic>;
    final text = decoded['text'];
    if (text is! String || text.isEmpty) {
      throw const FormatException('heads-up needs a text');
    }
    final roleId = event.tags
        .where((t) => t.first == 'role')
        .map((t) => t[1])
        .firstOrNull;
    final typeName = decoded['type'] as String?;
    final type = typeName == 'alert' ? HeadsUpType.alert : HeadsUpType.news;
    final escalationTag = event.tags
        .where((t) => t.first == 'escalation')
        .map((t) => t[1])
        .firstOrNull;
    return HeadsUp(
      text: text,
      author: event.pubKey,
      createdAt: event.createdAt,
      scope: roleId == null ? null : FarmRole.fromIdOrNull(roleId),
      type: type,
      escalationTag: escalationTag,
    );
  }
}
