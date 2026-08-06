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

const String _defaultRelay = String.fromEnvironment(
  'FARMCHORE_RELAY',
  defaultValue: 'ws://localhost:7447',
);

const String _productionRelay = String.fromEnvironment(
  'FARMCHORE_RELAY',
  defaultValue: 'wss://farmchore.fly.dev',
);

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

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Timer? _syncTimer;
  SyncService? _sync;
  bool _loading = true;
  String? _error;
  _Session? _session;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final relayConfig = RelayConfig(prefs);

      if (relayConfig.url == null) {
        // Show welcome screen inline — no Navigator.push.
        setState(() => _loading = false);
        return;
      }

      await _startSession(relayConfig);
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _startSession(RelayConfig relayConfig) async {
    final relayUrl = relayConfig.url ?? _defaultRelay;
    final apiKey = relayConfig.apiKey;
    print('[bootstrap] relay=$relayUrl');

    final keyStorage = kIsWeb
        ? _SharedPrefsKeyStorage(await SharedPreferences.getInstance())
        : SecureKeyStorage();
    print('[bootstrap] key storage ready');

    final identity = await IdentityService(keyStorage).ensureIdentity();
    print('[bootstrap] identity ready');

    final database = await AppDatabase.open();
    print('[bootstrap] database ready');

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
    unawaited(EscalationService(repository).check());

    if (kIsWeb) {
      NotificationService.requestPermission();
      NotificationService.connectBackgroundRelay(
        relayUrl,
        identity.pubkey,
        apiKey: apiKey,
      );
    }

    print('[bootstrap] done');
    setState(() {
      _session = _Session(
        repository: repository,
        myPubkey: identity.pubkey,
        relayUrl: relayUrl,
        relayConfig: relayConfig,
      );
      _loading = false;
    });
  }

  Future<void> _onRelaySelected(String relay, {String? apiKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final relayConfig = RelayConfig(prefs);
    await relayConfig.configure(url: relay, apiKey: apiKey);
    _sync?.stopLiveSubscription();
    _syncTimer?.cancel();
    await _startSession(relayConfig);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _sync?.stopLiveSubscription();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session != null) {
      return HomeShell(
        repository: _session!.repository,
        myPubkey: _session!.myPubkey,
        relayUrl: _session!.relayUrl,
        relayConfig: _session!.relayConfig,
      );
    }

    return _WelcomeScreen(
      onSelected: _onRelaySelected,
      error: _error,
    );
  }
}

class _WelcomeScreen extends StatefulWidget {
  const _WelcomeScreen({required this.onSelected, this.error});

  final Future<void> Function(String relay, {String? apiKey}) onSelected;
  final String? error;

  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen> {
  bool _busy = false;

  Future<void> _select(String relay, {String? apiKey}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSelected(relay, apiKey: apiKey);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Setup failed: $e',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: FarmColors.error,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Setting up...'),
            ],
          ),
        ),
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
              if (widget.error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: FarmColors.error,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.error!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
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
