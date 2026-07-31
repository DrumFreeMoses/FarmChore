import 'dart:convert';

import '../nostr/nostr_event.dart';

/// Kind for a member's display name (addressable by pubkey).
const int memberProfileKind = 31504;

/// A member's chosen display name (kind 31504, `d` = pubkey).
///
/// Anyone can read all profiles; only the owner's own pubkey signs theirs,
/// so a profile only counts for the pubkey that signed it.
class MemberProfile {
  const MemberProfile({required this.pubkey, required this.name});

  final String pubkey;
  final String name;

  /// Canonical addressable id: the member pubkey.
  String get dTag => pubkey;

  NostrEvent toNostrEvent({
    required String pubKey,
    required int createdAt,
    String? farmPubkey,
    List<List<String>> extraTags = const [],
  }) {
    return NostrEvent(
      pubKey: pubKey,
      createdAt: createdAt,
      kind: memberProfileKind,
      tags: [
        ['d', dTag],
        if (farmPubkey != null) ['farm', farmPubkey],
        ...extraTags,
      ],
      content: jsonEncode({'name': name}),
    );
  }

  factory MemberProfile.fromNostrEvent(NostrEvent event) {
    if (event.kind != memberProfileKind) {
      throw FormatException(
        'expected kind $memberProfileKind, got ${event.kind}',
      );
    }
    final dTag = event.tags
        .where((t) => t.isNotEmpty && t.first == 'd')
        .map((t) => t[1])
        .firstOrNull;
    if (dTag == null) {
      throw const FormatException('member profile needs a d tag (pubkey)');
    }
    final decoded = jsonDecode(event.content) as Map<String, dynamic>;
    final name = decoded['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('member profile needs a name');
    }
    return MemberProfile(pubkey: dTag, name: name);
  }
}
