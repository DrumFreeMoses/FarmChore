import 'dart:async';
import 'dart:convert';

import '../data/app_database.dart';
import '../data/chore_repository.dart';
import 'relay_connection.dart';

/// Outcome of one sync pass.
class SyncResult {
  const SyncResult({required this.pushed, required this.pulled});

  /// Events the relay acknowledged (duplicates are not counted).
  final int pushed;

  /// Remote events verified and imported into the local log.
  final int pulled;

  bool get anything => pushed > 0 || pulled > 0;
}

/// Two-way mirror with the FarmChore relay (NIP-01 over WebSocket).
///
/// Push: every locally-queued event (sent=false) is sent; it is marked sent
/// on OK(true) or a duplicate rejection, and retried on any other rejection.
/// Pull: a REQ over all FarmChore kinds imports remote events (id and
/// signature verified) into the local log. LWW resolution between
/// conflicting events stays in the readers, which pick the newest event per
/// address tag.
class SyncService {
  SyncService({
    required this.repository,
    required this.connectionFactory,
    this.timeout = const Duration(seconds: 10),
  });

  final ChoreRepository repository;
  final RelayConnection Function() connectionFactory;
  final Duration timeout;

  final Map<String, Completer<({bool accepted, String reason})>> _okWaiters =
      {};
  final Map<String, Completer<void>> _eoseWaiters = {};
  final List<Future<bool>> _imports = [];
  StreamSubscription<List<Object?>>? _subscription;

  /// Runs one sync pass. Never throws: an offline or broken relay just
  /// returns zero counts and leaves the outbound queue untouched.
  Future<SyncResult> sync({int since = 0}) async {
    var pushed = 0;
    var pulled = 0;
    RelayConnection? connection;
    try {
      connection = connectionFactory();
      await connection.connect();
      _subscription = connection.receive().listen(_handle);
      try {
        pushed = await _pushPending(connection);
        pulled = await _pull(connection, since: since);
      } finally {
        await _subscription?.cancel();
        _subscription = null;
      }
    } catch (_) {
      // Offline, malformed frames, or relay errors: stay silent, keep queue.
    } finally {
      await connection?.close();
    }
    return SyncResult(pushed: pushed, pulled: pulled);
  }

  void _handle(List<Object?> message) {
    if (message.isEmpty) return;
    switch (message.first) {
      case 'OK':
        if (message.length >= 4 && message[1] is String) {
          final waiter = _okWaiters.remove(message[1]);
          if (waiter != null) {
            waiter.complete((
              accepted: message[2] == true,
              reason: (message[3] as String?) ?? '',
            ));
          }
        }
      case 'EVENT':
        if (message.length >= 3 && message[2] is Map<String, dynamic>) {
          _imports.add(
            repository
                .importRemoteEvent(message[2] as Map<String, dynamic>)
                .catchError((_) => false),
          );
        }
      case 'EOSE':
        if (message.length >= 2 && message[1] is String) {
          final waiter = _eoseWaiters.remove(message[1]);
          if (waiter != null) {
            waiter.complete();
          }
        }
    }
  }

  Future<int> _pushPending(RelayConnection connection) async {
    final pending = await repository.pendingEvents();
    var pushed = 0;
    for (final event in pending) {
      final waiter = Completer<({bool accepted, String reason})>();
      _okWaiters[event.id] = waiter;
      await connection.send(['EVENT', _toJson(event)]);
      final ok = await waiter.future.timeout(
        timeout,
        onTimeout: () => (accepted: false, reason: 'timeout'),
      );
      _okWaiters.remove(event.id);
      if (ok.accepted || ok.reason.contains('duplicate')) {
        await repository.markSent(event.id);
        if (ok.accepted) {
          pushed++;
        }
      }
    }
    return pushed;
  }

  Future<int> _pull(RelayConnection connection, {required int since}) async {
    final imports = _imports;
    final subId = 'sync-${DateTime.now().microsecondsSinceEpoch}';
    final eose = Completer<void>();
    _eoseWaiters[subId] = eose;
    await connection.send([
      'REQ',
      subId,
      {'kinds': ChoreRepository.syncKinds, 'since': since},
    ]);
    try {
      await eose.future.timeout(timeout);
    } catch (_) {
      // No EOSE (dropped connection): keep whatever arrived.
    }
    final results = await Future.wait(imports);
    _imports.clear();
    return results.where((ok) => ok).length;
  }

  Map<String, Object?> _toJson(Event event) => {
    'id': event.id,
    'pubkey': event.pubkey,
    'created_at': event.createdAt,
    'kind': event.kind,
    'tags': jsonDecode(event.tags),
    'content': event.content,
    'sig': event.sig,
  };
}
