import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/status_actions_sheet.dart';

/// Today's instances assigned to my pubkey, across all roles.
/// Quick actions mark them done (or skip/defer/cancel).
class MyChoresScreen extends StatefulWidget {
  const MyChoresScreen({
    super.key,
    required this.repository,
    required this.myPubkey,
    this.today,
  });

  final ChoreRepository repository;
  final String myPubkey;
  final DateTime? today;

  @override
  State<MyChoresScreen> createState() => _MyChoresScreenState();
}

class _MyChoresScreenState extends State<MyChoresScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  List<ChoreInstance> _mine = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final instances = await widget.repository.loadInstancesForDate(_today);
    if (!mounted) return;
    setState(() {
      _mine = instances
          .where((i) => i.assignee == widget.myPubkey)
          .where((i) => i.status.isRemaining)
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Chores')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _mine.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('Nothing assigned to you today.'),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _mine.length,
                      itemBuilder: (context, index) {
                        final instance = _mine[index];
                        return ChoreCard(
                          instance: instance,
                          onTap: () => showStatusActions(
                            context: context,
                            repository: widget.repository,
                            instance: instance,
                            today: _today,
                            onChanged: _refresh,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
