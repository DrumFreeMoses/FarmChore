import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nostr/nostr.dart' as nostr;

/// A NIP-01 event: the unit of sync and the audit trail.
class NostrEvent {
  const NostrEvent({
    this.id,
    required this.pubKey,
    required this.createdAt,
    required this.kind,
    this.tags = const [],
    this.content = '',
    this.sig,
  });

  /// Event id (sha256 of the canonical serialization). Set at signing time.
  final String? id;
  final String pubKey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String? sig;

  /// NIP-01 canonical serialization: compact JSON, no whitespace.
  String canonicalSerialization() {
    final tagsJson = jsonEncode(tags);
    final contentJson = jsonEncode(content);
    return '[0,"$pubKey",$createdAt,$kind,$tagsJson,$contentJson]';
  }

  /// Event id: sha256 of the canonical serialization.
  String get computedId {
    final bytes = utf8.encode(canonicalSerialization());
    return sha256.convert(bytes).toString();
  }

  String get idOrComputed => id ?? computedId;

  /// Signs this event with [keys], producing a NIP-01 event id and
  /// Schnorr signature over the canonical serialization.
  NostrEvent signed(nostr.Keys keys) {
    final id = computedId;
    final sig = keys.sign(message: id);
    return NostrEvent(
      id: id,
      pubKey: pubKey,
      createdAt: createdAt,
      kind: kind,
      tags: tags,
      content: content,
      sig: sig,
    );
  }

  /// Verifies the event id and Schnorr signature against [pubKey].
  bool verifySignature() {
    final id = this.id;
    final sig = this.sig;
    if (id == null || sig == null) {
      return false;
    }
    if (id != computedId) {
      return false;
    }
    try {
      return nostr.Schnorr.verify(
        publicKey: pubKey,
        message: id,
        signature: sig,
      );
    } catch (_) {
      return false;
    }
  }

  NostrEvent copyWith({
    String? id,
    List<List<String>>? tags,
    String? content,
    String? sig,
  }) {
    return NostrEvent(
      id: id ?? this.id,
      pubKey: pubKey,
      createdAt: createdAt,
      kind: kind,
      tags: tags ?? this.tags,
      content: content ?? this.content,
      sig: sig ?? this.sig,
    );
  }
}
