import 'package:flutter/material.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/identity/key_storage.dart';
import 'package:farm_chore/identity/identity_service.dart';
import 'package:farm_chore/screens/home_shell.dart';
import 'package:farm_chore/theme/farm_theme.dart';

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
  late final Future<_Session> _session = _open();

  Future<_Session> _open() async {
    final identity = await IdentityService(SecureKeyStorage()).ensureIdentity();
    final database = await AppDatabase.open();
    return _Session(
      repository: ChoreRepository(database: database, keys: identity.keys),
      myPubkey: identity.pubkey,
    );
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
