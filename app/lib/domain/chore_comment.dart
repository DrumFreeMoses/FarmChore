import 'dart:convert';

import '../nostr/nostr_event.dart';

/// Kind for a comment on a chore instance.
const int choreCommentKind = 31507;

/// A comment on a specific chore instance (kind 31507).
///
/// Comments are addressable by `instanceDTag|author|createdAt` so each
/// comment is unique and the latest wins on the relay.
class ChoreComment {
  const ChoreComment({
    required this.text,
    required this.author,
    required this.createdAt,
    required this.instanceDTag,
  });

  final String text;
  final String author;
  final int createdAt;

  /// The `d` tag of the chore instance this comment is on.
  final String instanceDTag;

  /// Addressable id: instanceDTag + author + createdAt.
  String get dTag => '$instanceDTag|$author|$createdAt';

  NostrEvent toNostrEvent({
    required String pubKey,
    required int createdAt,
    String? farmPubkey,
    List<List<String>> extraTags = const [],
  }) {
    return NostrEvent(
      pubKey: pubKey,
      createdAt: createdAt,
      kind: choreCommentKind,
      tags: [
        ['d', dTag],
        ['e', instanceDTag],
        if (farmPubkey != null) ['farm', farmPubkey],
        ...extraTags,
      ],
      content: jsonEncode({'text': text}),
    );
  }

  factory ChoreComment.fromNostrEvent(NostrEvent event) {
    if (event.kind != choreCommentKind) {
      throw FormatException(
        'expected kind $choreCommentKind, got ${event.kind}',
      );
    }
    final dTag = event.tags
        .where((t) => t.isNotEmpty && t.first == 'd')
        .map((t) => t[1])
        .firstOrNull;
    if (dTag == null) {
      throw const FormatException('comment needs a d tag');
    }
    final decoded = jsonDecode(event.content) as Map<String, dynamic>;
    final text = decoded['text'];
    if (text is! String || text.isEmpty) {
      throw const FormatException('comment needs a text');
    }
    // Parse instanceDTag from the d tag: everything before the last two `|` segments.
    final parts = dTag.split('|');
    // dTag format: instanceDTag|author|createdAt
    // instanceDTag itself contains `|` (date|role|slug), so we need to reconstruct.
    // instanceDTag = parts[0..-3].join('|'), author = parts[-2], createdAt = parts[-1]
    if (parts.length < 3) {
      throw const FormatException('comment d tag has invalid format');
    }
    final instanceDTag = parts.sublist(0, parts.length - 2).join('|');
    return ChoreComment(
      text: text,
      author: event.pubKey,
      createdAt: event.createdAt,
      instanceDTag: instanceDTag,
    );
  }
}
