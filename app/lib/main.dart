import 'dart:async';

import 'package:flutter/material.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/identity/key_storage.dart';
import 'package:farm_chore/identity/identity_service.dart';
import 'package:farm_chore/screens/home_shell.dart';
import 'package:farm_chore/sync/relay_connection.dart';
import 'package:farm_chore/sync/sync_service.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// Relay URL. Override at build time:
///   flutter run --dart-define=FARMCHORE_RELAY=ws://relay.farm.example
const String _relayUrl = String.fromEnvironment(
  'FARMCHORE_RELAY',
  defaultValue: 'ws://localhost:7447',
);

void main() {
  runApp(const FarmChoreApp());
}

class FarmChoreApp extends StatelessWidget {
  const FarmChoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmChore',
      theme: farmTheme(),
      home: const _Bootstrap(),
    );
  }
}

/// Resolves the identity and opens the database, then shows the shell.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Timer? _syncTimer;
  SyncService? _sync;
  late final Future<_Session> _session = _open();

  Future<_Session> _open() async {
    final identity = await IdentityService(SecureKeyStorage()).ensureIdentity();
    final database = await AppDatabase.open();
    final repository = ChoreRepository(database: database, keys: identity.keys);
    final sync = SyncService(
      repository: repository,
      connectionFactory: () => WebSocketRelayConnection(_relayUrl),
    );
    _sync = sync;
    // One-shot sync at startup.
    unawaited(sync.sync());
    // Keep a 1-minute fallback timer for pending push retries.
    _syncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(sync.sync()),
    );
    // Live subscription for real-time updates from other devices.
    sync.startLiveSubscription();
    return _Session(repository: repository, myPubkey: identity.pubkey);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _sync?.stopLiveSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Session>(
      future: _session,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data!;
        return HomeShell(
          repository: session.repository,
          myPubkey: session.myPubkey,
        );
      },
    );
  }
}

class _Session {
  const _Session({required this.repository, required this.myPubkey});

  final ChoreRepository repository;
  final String myPubkey;
}
