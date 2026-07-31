import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/edit_event.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/history_screen.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/edit_instance_dialog.dart';
import 'package:nostr/nostr.dart';

Future<ChoreRepository> seeded({required DateTime today}) async {
  final db = await AppDatabase.openInMemory();
  final repo = ChoreRepository(
    database: db,
    keys: Keys.generate(),
    farmPubkey: 'f' * 64,
  );
  await repo.saveRoleDefaultSet(
    const RoleDefaultSet(
      role: FarmRole.milkers,
      chores: [
        ChoreDefault(title: 'Morning milking', weekdays: [1, 2, 3, 4, 5, 6]),
      ],
    ),
  );
  await repo.ensureDayGenerated(today);
  await repo.ensureDayGenerated(today.subtract(const Duration(days: 1)));
  await repo.ensureDayGenerated(today.subtract(const Duration(days: 2)));
  return repo;
}

void main() {
  final today = DateTime(2026, 7, 31);

  testWidgets('history lists instances with date headers', (tester) async {
    final repo = await seeded(today: today);
    addTearDown(repo.database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: HistoryScreen(repository: repo, today: today),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morning milking'), findsNWidgets(3));
    expect(find.text('07/29/2026'), findsOneWidget);
    expect(find.text('07/31/2026'), findsOneWidget);
  });

  testWidgets('filters history by role', (tester) async {
    final repo = await seeded(today: today);
    addTearDown(repo.database.close);
    await repo.saveRoleDefaultSet(
      const RoleDefaultSet(
        role: FarmRole.feeders,
        chores: [
          ChoreDefault(title: 'Feed calves', weekdays: [1, 2, 3, 4, 5, 6]),
        ],
      ),
    );
    await repo.ensureDayGenerated(today);

    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: HistoryScreen(repository: repo, today: today),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All roles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Feeder's Chores").last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Feed calves'), findsOneWidget);
    expect(find.text('Morning milking'), findsNothing);
  });

  group('edit scope', () {
    test(
      'updateTitle default scope also rewrites the role default set',
      () async {
        final repo = await seeded(today: today);
        addTearDown(repo.database.close);

        final instance = (await repo.loadInstancesForDate(today)).single;
        await repo.updateTitle(
          instance,
          'Milking AM',
          scope: EditScope.default_,
        );

        final reloaded = (await repo.loadInstancesForDate(today)).single;
        expect(reloaded.title, 'Milking AM');
        final defaults = await repo.loadRoleDefaultSets();
        expect(defaults.single.chores.single.title, 'Milking AM');
      },
    );

    test('updateTitle one-time leaves the default set alone', () async {
      final repo = await seeded(today: today);
      addTearDown(repo.database.close);

      final instance = (await repo.loadInstancesForDate(today)).single;
      await repo.updateTitle(instance, 'Milking AM');

      final reloaded = (await repo.loadInstancesForDate(today)).single;
      expect(reloaded.title, 'Milking AM');
      final defaults = await repo.loadRoleDefaultSets();
      expect(defaults.single.chores.single.title, 'Morning milking');
    });
  });

  testWidgets('edit dialog offers one-time vs default and saves', (
    tester,
  ) async {
    final repo = await seeded(today: today);
    addTearDown(repo.database.close);

    final instance = (await repo.loadInstancesForDate(today)).single;
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => EditInstanceDialog.show(
                  context,
                  instance: instance,
                  repository: repo,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Just today'), findsOneWidget);
    expect(find.text('Update default'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Evening milking');
    await tester.tap(find.text('Update default'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final reloaded = (await repo.loadInstancesForDate(today)).single;
    expect(reloaded.title, 'Evening milking');
    final defaults = await repo.loadRoleDefaultSets();
    expect(defaults.single.chores.single.title, 'Evening milking');
  });
}
