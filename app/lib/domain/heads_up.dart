import 'dart:convert';

import 'roles.dart';
import '../nostr/nostr_event.dart';

/// Kind for a farm heads-up notice (weather, alerts, reminders, news).
const int headsUpKind = 31505;

/// A short farm notice (kind 31505). Scoped to the whole farm or to one
/// role group; authored by any member.
class HeadsUp {
  const HeadsUp({
    required this.text,
    required this.author,
    required this.createdAt,
    this.scope,
  });

  final String text;

  /// Pubkey of the member who wrote it.
  final String author;

  final int createdAt;

  /// Null = farm-wide; a role id = for that role's group.
  final FarmRole? scope;

  /// Addressable id: author + creation time (unique per author per second).
  String get dTag => '$author-$createdAt';

  bool get isFarmWide => scope == null;

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
        ...extraTags,
      ],
      content: jsonEncode({'text': text}),
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
    return HeadsUp(
      text: text,
      author: event.pubKey,
      createdAt: event.createdAt,
      scope: roleId == null ? null : FarmRole.fromIdOrNull(roleId),
    );
  }
}
