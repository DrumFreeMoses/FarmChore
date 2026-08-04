import 'dart:convert';

import '../nostr/nostr_event.dart';

/// Kind for a member's display name (addressable by pubkey).
const int memberProfileKind = 31504;

/// A member's profile (kind 31504, `d` = pubkey).
///
/// Anyone can read all profiles; only the owner's own pubkey signs theirs,
/// so a profile only counts for the pubkey that signed it.
class MemberProfile {
  const MemberProfile({
    required this.pubkey,
    required this.name,
    this.dayOff,
    this.skills = const [],
  });

  final String pubkey;
  final String name;

  /// Weekday off (1=Monday .. 7=Sunday), or null for no regular day off.
  final int? dayOff;

  /// Skill tags this member has (e.g. `milker`, `skid-loader`, `tractor`).
  final List<String> skills;

  /// Canonical addressable id: the member pubkey.
  String get dTag => pubkey;

  /// True when [member] has all [requiredSkills].
  bool hasSkills(List<String> requiredSkills) =>
      requiredSkills.every((s) => skills.contains(s));

  /// True when this member is off on [weekday].
  bool isOffOn(int weekday) => dayOff == weekday;

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
      content: jsonEncode({
        'name': name,
        if (dayOff != null) 'dayOff': dayOff,
        if (skills.isNotEmpty) 'skills': skills,
      }),
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
    final dayOff = decoded['dayOff'] as int?;
    final skills = (decoded['skills'] as List?)?.cast<String>() ?? const [];
    return MemberProfile(
      pubkey: dTag,
      name: name,
      dayOff: dayOff,
      skills: skills,
    );
  }

  MemberProfile copyWith({
    String? name,
    int? dayOff,
    bool clearDayOff = false,
    List<String>? skills,
  }) => MemberProfile(
    pubkey: pubkey,
    name: name ?? this.name,
    dayOff: clearDayOff ? null : (dayOff ?? this.dayOff),
    skills: skills ?? this.skills,
  );
}
