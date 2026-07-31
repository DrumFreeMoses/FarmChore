import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/data/demo_seed.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/dashboard_screen.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:nostr/nostr.dart';

void main() {
  final friday = DateTime(2026, 7, 31);

  group('seedFarmDefaults', () {
    test('creates a default set for every role', () async {
      final db = await AppDatabase.openInMemory();
      addTearDown(db.close);
      final repo = ChoreRepository(database: db, keys: Keys.generate());

      await seedFarmDefaults(repo);

      final sets = await repo.loadRoleDefaultSets();
      expect(sets.length, FarmRoles.all.length);
      for (final role in FarmRoles.all) {
        expect(
          sets.any((s) => s.role == role),
          isTrue,
          reason: 'missing defaults for ${role.id}',
        );
      }
    });

    test('is idempotent: re-seeding never duplicates', () async {
      final db = await AppDatabase.openInMemory();
      addTearDown(db.close);
      final repo = ChoreRepository(database: db, keys: Keys.generate());

      await seedFarmDefaults(repo);
      await seedFarmDefaults(repo);

      final sets = await repo.loadRoleDefaultSets();
      expect(sets.length, FarmRoles.all.length);
    });

    test('generates instances for every role on a workday', () async {
      final db = await AppDatabase.openInMemory();
      addTearDown(db.close);
      final repo = ChoreRepository(database: db, keys: Keys.generate());

      await seedFarmDefaults(repo);
      await repo.ensureDayGenerated(friday);

      final instances = await repo.loadInstancesForDate(friday);
      expect(instances, isNotEmpty);
      for (final role in FarmRoles.all) {
        expect(
          instances.any((i) => i.role == role),
          isTrue,
          reason: 'no Friday work for ${role.id}',
        );
      }
    });

    test(
      'weekday filtering: mechanics do not sharpen tools on Fridays',
      () async {
        final db = await AppDatabase.openInMemory();
        addTearDown(db.close);
        final repo = ChoreRepository(database: db, keys: Keys.generate());

        await seedFarmDefaults(repo);
        await repo.ensureDayGenerated(friday);

        final instances = await repo.loadInstancesForDate(friday);
        // Friday is weekday 5: no tool sharpening (Wed), no fence (Mon/Thu),
        // but equipment repair (Tue/Fri).
        expect(instances.any((i) => i.title == 'Sharpen tools'), isFalse);
        expect(instances.any((i) => i.title == 'Fix fence'), isFalse);
        expect(instances.any((i) => i.title == 'Equipment repair'), isTrue);
      },
    );
  });

  testWidgets('dashboard offers demo data when empty, then fills up', (
    tester,
  ) async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = ChoreRepository(database: db, keys: Keys.generate());

    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: DashboardScreen(repository: repo, today: friday),
      ),
    );
    await tester.pumpAndSettle();

    // List mode shows the per-role empty state; grid mode shows headers.
    await tester.tap(find.byTooltip('Show list'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Load demo data'), findsOneWidget);
    expect(find.text('No chores today'), findsNWidgets(6));

    await tester.tap(find.byTooltip('Load demo data'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Load demo data'), findsNothing);
    expect(find.text("Milker's Chores"), findsOneWidget);
    expect(find.text('3 open'), findsOneWidget); // Pourers: 3 Friday chores
    expect(find.text('Morning milking'), findsOneWidget);
    expect(find.text('Bottle milk for shares'), findsOneWidget);
    expect(find.text('No chores today'), findsNothing);
  });
}
