import 'dart:convert';

import '../nostr/nostr_event.dart';

/// Kind for a farm message (DM or broadcast).
const int farmMessageKind = 31506;

/// A message between farm members (kind 31506).
///
/// - [recipient] = null → farm-wide broadcast (visible to all members).
/// - [recipient] = pubkey → direct message to that member.
class FarmMessage {
  const FarmMessage({
    required this.text,
    required this.author,
    required this.createdAt,
    this.recipient,
  });

  final String text;

  /// Pubkey of the sender.
  final String author;

  final int createdAt;

  /// Pubkey of the recipient, or null for farm-wide broadcast.
  final String? recipient;

  /// Addressable id: author + creation time.
  String get dTag => '$author-$createdAt';

  bool get isDirect => recipient != null;
  bool get isBroadcast => recipient == null;

  /// Conversation key: sorted pair of pubkeys for DMs, or 'farm' for broadcast.
  String conversationWith(String myPubkey) {
    if (isBroadcast) return 'farm';
    if (recipient == myPubkey) return author;
    return recipient!;
  }

  NostrEvent toNostrEvent({
    required String pubKey,
    required int createdAt,
    String? farmPubkey,
    List<List<String>> extraTags = const [],
  }) {
    return NostrEvent(
      pubKey: pubKey,
      createdAt: createdAt,
      kind: farmMessageKind,
      tags: [
        ['d', dTag],
        if (recipient != null) ['p', recipient!],
        if (farmPubkey != null) ['farm', farmPubkey],
        ...extraTags,
      ],
      content: jsonEncode({'text': text}),
    );
  }

  factory FarmMessage.fromNostrEvent(NostrEvent event) {
    if (event.kind != farmMessageKind) {
      throw FormatException(
        'expected kind $farmMessageKind, got ${event.kind}',
      );
    }
    final dTag = event.tags
        .where((t) => t.isNotEmpty && t.first == 'd')
        .map((t) => t[1])
        .firstOrNull;
    if (dTag == null) {
      throw const FormatException('message needs a d tag');
    }
    final decoded = jsonDecode(event.content) as Map<String, dynamic>;
    final text = decoded['text'];
    if (text is! String || text.isEmpty) {
      throw const FormatException('message needs a text');
    }
    final recipient = event.tags
        .where((t) => t.first == 'p')
        .map((t) => t[1])
        .firstOrNull;
    return FarmMessage(
      text: text,
      author: event.pubKey,
      createdAt: event.createdAt,
      recipient: recipient,
    );
  }
}
