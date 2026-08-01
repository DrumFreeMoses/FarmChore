import 'dart:async';

import 'package:flutter/material.dart';
import 'package:farm_chore/data/chore_repository.dart';

/// Shows the sync status: a green dot when the queue is empty, an amber badge
/// with the pending count when events are waiting to be pushed, and a manual
/// sync button.
class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key, required this.repository, this.onSync});

  final ChoreRepository repository;

  /// Called when the user taps the badge to trigger a manual sync.
  final VoidCallback? onSync;

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  int _pendingCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final pending = await widget.repository.pendingEvents();
    if (!mounted) return;
    setState(() => _pendingCount = pending.length);
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingCount == 0) {
      return IconButton(
        icon: const Icon(Icons.cloud_done, size: 20),
        tooltip: 'Synced',
        onPressed: widget.onSync,
      );
    }
    return IconButton(
      icon: Badge(
        label: Text('$_pendingCount'),
        child: const Icon(Icons.cloud_upload_outlined, size: 20),
      ),
      tooltip: '$_pendingCount events pending sync',
      onPressed: widget.onSync,
    );
  }
}
