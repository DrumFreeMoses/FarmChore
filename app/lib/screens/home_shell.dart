import 'package:flutter/material.dart';
import 'package:farm_chore/config/relay_config.dart';
import 'package:farm_chore/data/chore_repository.dart';

import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'message_screen.dart';
import 'my_chores_screen.dart';
import 'news_screen.dart';
import 'undone_chores_screen.dart';

/// App shell: bottom navigation over the five farm views.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.myPubkey,
    required this.relayUrl,
    required this.relayConfig,
    this.today,
  });

  final ChoreRepository repository;
  final String myPubkey;
  final String relayUrl;
  final RelayConfig relayConfig;
  final DateTime? today;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        repository: widget.repository,
        today: widget.today,
        relayUrl: widget.relayUrl,
        relayConfig: widget.relayConfig,
      ),
      MyChoresScreen(
        repository: widget.repository,
        myPubkey: widget.myPubkey,
        today: widget.today,
      ),
      UndoneChoresScreen(repository: widget.repository, today: widget.today),
      HistoryScreen(repository: widget.repository, today: widget.today),
      NewsScreen(repository: widget.repository),
      MessageScreen(repository: widget.repository, myPubkey: widget.myPubkey),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.person), label: 'My Chores'),
          NavigationDestination(
            icon: Icon(Icons.pending_actions),
            label: 'Remaining',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.campaign), label: 'News'),
          NavigationDestination(icon: Icon(Icons.message), label: 'Messages'),
        ],
      ),
    );
  }
}
