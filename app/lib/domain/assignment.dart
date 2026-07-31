import '../nostr/nostr_event.dart';

/// Kind for assigning an instance (31501) to a member.
const int assignmentKind = 31502;

/// Assignment or self-assignment of an instance to a member (kind 31502).
class Assignment {
  const Assignment({required this.instanceId, required this.assignee});

  /// Event id of the assigned ChoreInstance (31501).
  final String instanceId;

  /// Pubkey of the assigned member.
  final String assignee;

  bool isSelfAssign(String pubKey) => pubKey == assignee;

  /// Serializes as a signed-ready kind 31502 event. The caller signs and
  /// stores the result.
  NostrEvent toNostrEvent({
    required String pubKey,
    required int createdAt,
    String? farmPubkey,
    List<List<String>> extraTags = const [],
  }) {
    return NostrEvent(
      pubKey: pubKey,
      createdAt: createdAt,
      kind: assignmentKind,
      tags: [
        ['e', instanceId],
        ['p', assignee],
        if (farmPubkey != null) ['farm', farmPubkey],
        ...extraTags,
      ],
      content: '',
    );
  }

  /// Parses a kind 31502 event back into an assignment.
  factory Assignment.fromNostrEvent(NostrEvent event) {
    if (event.kind != assignmentKind) {
      throw FormatException('expected kind $assignmentKind, got ${event.kind}');
    }
    String? tagValue(List<String> tag) => tag.length > 1 ? tag[1] : null;
    final instanceId = event.tags
        .where((t) => t.first == 'e')
        .map(tagValue)
        .firstOrNull;
    final assignee = event.tags
        .where((t) => t.first == 'p')
        .map(tagValue)
        .firstOrNull;
    if (instanceId == null) {
      throw const FormatException('assignment needs an e tag (instance id)');
    }
    if (assignee == null) {
      throw const FormatException('assignment needs a p tag (assignee)');
    }
    return Assignment(instanceId: instanceId, assignee: assignee);
  }
}
