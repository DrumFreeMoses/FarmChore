import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/chore_card.dart';
import 'package:farm_chore/widgets/new_item_dialog.dart';

/// Read-only history of instances over the last 3 months, filterable by
/// role, member, and chore title.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository, this.today});

  final ChoreRepository repository;
  final DateTime? today;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late final DateTime _from = DateTime(
    _today.year,
    _today.month - 3,
    _today.day,
  );
  List<ChoreInstance> _all = [];
  List<ChoreInstance> _filtered = [];
  Map<String, String> _names = {};
  FarmRole? _roleFilter;
  String? _assigneeFilter;
  String _titleQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _all = await widget.repository.loadInstancesBetween(_from, _today);
    final names = await widget.repository.loadMemberNames();
    if (!mounted) return;
    setState(() {
      _names = names;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    _filtered = _all.where((i) {
      if (_roleFilter != null && i.role != _roleFilter) return false;
      if (_assigneeFilter != null && i.assignee != _assigneeFilter) {
        return false;
      }
      if (_titleQuery.isNotEmpty &&
          !i.title.toLowerCase().contains(_titleQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  Set<String> get _assignees =>
      _all.map((i) => i.assignee).whereType<String>().toSet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Filter',
            onPressed: () => _showFilters(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New chore or task',
        onPressed: () async {
          final created = await showNewItemDialog(
            context: context,
            repository: widget.repository,
            today: _today,
          );
          if (created && mounted) _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _filtered.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('Nothing here yet.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final instance = _filtered[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index == 0 ||
                                !_sameDay(
                                  _filtered[index - 1].date,
                                  instance.date,
                                ))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  0,
                                ),
                                child: Text(
                                  _formatDate(instance.date),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(color: FarmColors.sabbath),
                                ),
                              ),
                            ChoreCard(instance: instance, memberNames: _names),
                          ],
                        );
                      },
                    ),
            ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Chore title contains',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    setSheetState(() {
                      _titleQuery = v;
                      _applyFilters();
                    });
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                DropdownButton<FarmRole?>(
                  value: _roleFilter,
                  hint: const Text('All roles'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All roles'),
                    ),
                    for (final role in FarmRoles.all)
                      DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      ),
                  ],
                  onChanged: (v) {
                    setSheetState(() {
                      _roleFilter = v;
                      _applyFilters();
                    });
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  value: _assigneeFilter,
                  hint: const Text('All members'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All members'),
                    ),
                    for (final member in _assignees)
                      DropdownMenuItem(
                        value: member,
                        child: Text(member.substring(0, 12)),
                      ),
                  ],
                  onChanged: (v) {
                    setSheetState(() {
                      _assigneeFilter = v;
                      _applyFilters();
                    });
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          _roleFilter = null;
                          _assigneeFilter = null;
                          _titleQuery = '';
                          _applyFilters();
                        });
                        setState(() {});
                      },
                      child: const Text('Clear filters'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
