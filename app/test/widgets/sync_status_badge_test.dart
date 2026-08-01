import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';

void main() {
  late AppDatabase db;
  late Keys keys;
  late ChoreRepository repo;

  setUp(() async {
    db = await AppDatabase.openInMemory();
    keys = Keys.generate();
    repo = ChoreRepository(database: db, keys: keys);
  });

  tearDown(() => db.close());

  Widget buildBadge({VoidCallback? onSync}) {
    return MaterialApp(
      home: Scaffold(
        body: SyncStatusBadge(repository: repo, onSync: onSync),
      ),
    );
  }

  group('SyncStatusBadge', () {
    testWidgets('shows green cloud when queue is empty', (tester) async {
      await tester.pumpWidget(buildBadge());
      await tester.pump();

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
    });

    testWidgets('shows badge with count when events are pending', (
      tester,
    ) async {
      final instance = ChoreInstance(
        date: DateTime(2026, 7, 31),
        role: FarmRole.milkers,
        slug: 'milking-am',
        title: 'Morning milking',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);

      await tester.pumpWidget(buildBadge());
      await tester.pump();

      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('tapping badge calls onSync callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildBadge(onSync: () => tapped = true));
      await tester.pump();

      await tester.tap(find.byType(SyncStatusBadge));
      expect(tapped, isTrue);
    });
  });
}
