import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:farm_chore/config/relay_config.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/identity/key_storage.dart';
import 'package:farm_chore/identity/identity_service.dart';
import 'package:farm_chore/screens/home_shell.dart';
import 'package:farm_chore/screens/join_screen.dart';
import 'package:farm_chore/services/escalation_service.dart';
import 'package:farm_chore/services/notification_service.dart';
import 'package:farm_chore/sync/relay_connection.dart';
import 'package:farm_chore/sync/sync_service.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Build-time default relay URL. Overridden at build via:
///   flutter build web --dart-define=FARMCHORE_RELAY=wss://relay.farm.example
const String _defaultRelay = String.fromEnvironment(
  'FARMCHORE_RELAY',
  defaultValue: 'ws://localhost:7447',
);

/// Production relay for JSF. Embedded at build time.
const String _productionRelay = String.fromEnvironment(
  'FARMCHORE_RELAY',
  defaultValue: 'wss://farmchore.fly.dev',
);

/// Production API key. Embedded at build time.
const String _productionApiKey = String.fromEnvironment(
  'FARMCHORE_API_KEY',
  defaultValue: '21b03470afde01c22075cadb597b6e1d',
);

void main() {
  runApp(const FarmChoreApp());
}

class FarmChoreApp extends StatelessWidget {
  const FarmChoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmChore for Jacob Springs Farm',
      theme: farmTheme(),
      home: const _Bootstrap(),
    );
  }
}

/// Resolves identity, relay URL, and opens the database, then shows the shell.
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
    final prefs = await SharedPreferences.getInstance();
    final relayConfig = RelayConfig(prefs);

    // If no relay URL is stored, show the join/start screen.
    if (relayConfig.url == null) {
      if (!mounted) return Future.error(StateError('unmounted'));
      final chosen = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => _WelcomeScreen(relayConfig: relayConfig),
        ),
      );
      if (chosen == null) {
        // User backed out — stay on welcome screen.
        return Future.error(StateError('no relay chosen'));
      }
    }

    final relayUrl = relayConfig.url ?? _defaultRelay;
    final apiKey = relayConfig.apiKey;
    final identity = await IdentityService(SecureKeyStorage()).ensureIdentity();
    final database = await AppDatabase.open();
    final repository = ChoreRepository(database: database, keys: identity.keys);
    final sync = SyncService(
      repository: repository,
      connectionFactory: () =>
          WebSocketRelayConnection(relayUrl, apiKey: apiKey),
    );
    _sync = sync;
    unawaited(sync.sync());
    _syncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(sync.sync()),
    );
    sync.startLiveSubscription();

    // Run escalation check for overdue chores.
    unawaited(EscalationService(repository).check());

    // Connect the service worker for background notifications.
    if (kIsWeb) {
      NotificationService.requestPermission();
      NotificationService.connectBackgroundRelay(
        relayUrl,
        identity.pubkey,
        apiKey: apiKey,
      );
    }

    return _Session(
      repository: repository,
      myPubkey: identity.pubkey,
      relayUrl: relayUrl,
      relayConfig: relayConfig,
    );
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
        if (snapshot.hasError) {
          return _WelcomeScreen(
            relayConfig: RelayConfig(
              // This will be replaced on next interaction.
              // ignore: invalid_use_of_visible_for_testing_member
              SharedPreferences.getInstance() as dynamic,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data!;
        return HomeShell(
          repository: session.repository,
          myPubkey: session.myPubkey,
          relayUrl: session.relayUrl,
          relayConfig: session.relayConfig,
        );
      },
    );
  }
}

/// Welcome screen shown on first launch: join via QR or set up as owner.
class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.relayConfig});

  final RelayConfig relayConfig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.agriculture,
                size: 80,
                color: FarmColors.cottonwoodGreen,
              ),
              const SizedBox(height: 24),
              Text(
                'FarmChore',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Chore management for your farm',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: () async {
                  // Connect to the production relay with the built-in API key.
                  await relayConfig.configure(
                    url: _productionRelay,
                    apiKey: _productionApiKey,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(_productionRelay);
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Set up as farm owner'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final relay = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => JoinScreen(relayConfig: relayConfig),
                    ),
                  );
                  if (relay != null && context.mounted) {
                    Navigator.of(context).pop(relay);
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Join via QR code'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await relayConfig.setUrl(_defaultRelay);
                  if (context.mounted) {
                    Navigator.of(context).pop(_defaultRelay);
                  }
                },
                child: const Text('Use local relay (dev only)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Session {
  const _Session({
    required this.repository,
    required this.myPubkey,
    required this.relayUrl,
    required this.relayConfig,
  });

  final ChoreRepository repository;
  final String myPubkey;
  final String relayUrl;
  final RelayConfig relayConfig;
}
