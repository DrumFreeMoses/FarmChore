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
  Future<_Session>? _session;

  @override
  void initState() {
    super.initState();
    _session = _open();
  }

  Future<_Session> _open() async {
    final prefs = await SharedPreferences.getInstance();
    final relayConfig = RelayConfig(prefs);

    // If no relay URL is stored, show the join/start screen.
    if (relayConfig.url == null) {
      if (!mounted) return Future.error(StateError('unmounted'));
      final chosen = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => _WelcomeScreen(
            onSelected: (relay, key) async {
              await relayConfig.configure(url: relay, apiKey: key);
              if (mounted) {
                Navigator.of(context).pop(relay);
              }
            },
          ),
        ),
      );
      if (chosen == null) {
        return Future.error(StateError('no relay chosen'));
      }
    }

    return _bootstrap(relayConfig);
  }

  Future<_Session> _bootstrap(RelayConfig relayConfig) async {
    final relayUrl = relayConfig.url ?? _defaultRelay;
    final apiKey = relayConfig.apiKey;
    // On web, FlutterSecureStorage can hang; use SharedPreferences for keys.
    final keyStorage = kIsWeb
        ? _SharedPrefsKeyStorage(await SharedPreferences.getInstance())
        : SecureKeyStorage();
    final identity = await IdentityService(keyStorage).ensureIdentity();
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

  void _retry() {
    _sync?.stopLiveSubscription();
    _syncTimer?.cancel();
    setState(() {
      _session = _open();
    });
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
            onSelected: (relay, key) async {
              final prefs = await SharedPreferences.getInstance();
              final relayConfig = RelayConfig(prefs);
              await relayConfig.configure(url: relay, apiKey: key);
              _retry();
            },
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

/// Callback when a relay is selected: (relayUrl, apiKey?).
typedef OnRelaySelected = Future<void> Function(String relay, String? apiKey);

/// Welcome screen shown on first launch or after error.
class _WelcomeScreen extends StatefulWidget {
  const _WelcomeScreen({required this.onSelected});

  final OnRelaySelected onSelected;

  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen> {
  bool _loading = false;

  Future<void> _select(String relay, {String? apiKey}) async {
    if (_loading) return;
    setState(() => _loading = true);
    await widget.onSelected(relay, apiKey);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
                onPressed: () =>
                    _select(_productionRelay, apiKey: _productionApiKey),
                icon: const Icon(Icons.person_add),
                label: const Text('Set up as farm owner'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final relayConfig = RelayConfig(
                    await SharedPreferences.getInstance(),
                  );
                  if (!mounted) return;
                  final relay = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => JoinScreen(relayConfig: relayConfig),
                    ),
                  );
                  if (relay != null && mounted) {
                    await _select(relay);
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Join via QR code'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _select(_defaultRelay),
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

/// Web-compatible key storage using SharedPreferences (localStorage).
/// FlutterSecureStorage hangs on web because it depends on a native keychain.
class _SharedPrefsKeyStorage implements KeyStorage {
  _SharedPrefsKeyStorage(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'farmchore_member_nsec';

  @override
  Future<void> save(String nsec) => _prefs.setString(_key, nsec);

  @override
  Future<String?> load() async => _prefs.getString(_key);

  @override
  Future<void> clear() => _prefs.remove(_key);
}
