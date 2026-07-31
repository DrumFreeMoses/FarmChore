import 'dart:convert';

import '../nostr/nostr_event.dart';

/// Kind for an edit revision of an instance or default.
const int editKind = 31503;

/// Whether an edit applies to this instance only, or also rewrites the
/// role default set (persistent change).
enum EditScope { oneTime, default_ }

/// A signed edit revision (kind 31503): the audit trail for every change.
class EditEvent {
  const EditEvent({
    required this.instanceId,
    required this.field,
    required this.value,
    this.scope = EditScope.oneTime,
  });

  /// Addressable id (d tag) of the edited instance or default.
  final String instanceId;

  /// Which field changed: `status`, `title`, `weekdays`, ...
  final String field;
  final String value;
  final EditScope scope;

  /// Serializes as a signed-ready kind 31503 event. The caller signs and
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
      kind: editKind,
      tags: [
        ['e', instanceId],
        ['d', instanceId],
        if (farmPubkey != null) ['farm', farmPubkey],
        ...extraTags,
      ],
      content: jsonEncode({
        'field': field,
        'value': value,
        'scope': scope == EditScope.oneTime ? 'one-time' : 'default',
      }),
    );
  }

  /// Parses a kind 31503 event back into an edit.
  factory EditEvent.fromNostrEvent(NostrEvent event) {
    if (event.kind != editKind) {
      throw FormatException('expected kind $editKind, got ${event.kind}');
    }
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(event.content) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('malformed edit content: $e');
    }
    final instanceId = event.tags
        .where((t) => t.first == 'e')
        .map((t) => t[1])
        .firstOrNull;
    if (instanceId == null) {
      throw const FormatException('edit needs an e tag (instance id)');
    }
    final field = decoded['field'];
    final value = decoded['value'];
    if (field is! String || value is! String) {
      throw const FormatException('edit needs field and value');
    }
    return EditEvent(
      instanceId: instanceId,
      field: field,
      value: value,
      scope: decoded['scope'] == 'default'
          ? EditScope.default_
          : EditScope.oneTime,
    );
  }
}
