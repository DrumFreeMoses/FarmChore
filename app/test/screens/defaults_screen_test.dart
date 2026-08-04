import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/defaults_screen.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:nostr/nostr.dart';

Future<ChoreRepository> seededRepo() async {
  final db = await AppDatabase.openInMemory();
  final repo = ChoreRepository(database: db, keys: Keys.generate());
  await repo.saveRoleDefaultSet(
    const RoleDefaultSet(
      role: FarmRole.pourers,
      chores: [
        ChoreDefault(title: 'Bottle milk', weekdays: [1, 2, 3, 4, 5, 6]),
        ChoreDefault(title: 'Fill fridge', weekdays: [1, 2, 3, 4, 5, 6]),
      ],
    ),
  );
  return repo;
}

void main() {
  final friday = DateTime(2026, 7, 31);

  test('variants do not leak into daily generation', () async {
    final repo = await seededRepo();
    addTearDown(repo.database.close);

    await repo.saveRoleVariant(FarmRole.pourers, 'Compressor down', const [
      ChoreDefault(title: 'Ice the milk', weekdays: [1, 2, 3, 4, 5, 6]),
      ChoreDefault(title: 'Churn by hand', weekdays: [1, 2, 3, 4, 5, 6]),
    ]);

    final base = await repo.loadBaseRoleDefaultSets();
    expect(base.length, 1);
    expect(base.single.chores.map((c) => c.title), contains('Bottle milk'));
    expect(
      base.single.chores.map((c) => c.title),
      isNot(contains('Ice the milk')),
    );

    final instances = await repo.loadInstancesForDate(friday);
    expect(instances.map((i) => i.title), isNot(contains('Ice the milk')));
  });

  test('activating a variant replaces the base set for generation', () async {
    final repo = await seededRepo();
    addTearDown(repo.database.close);
    final original = (await repo.loadBaseRoleDefaultSets()).single;

    await repo.saveRoleVariant(FarmRole.pourers, 'Compressor down', const [
      ChoreDefault(title: 'Ice the milk', weekdays: [1, 2, 3, 4, 5, 6]),
      ChoreDefault(title: 'Churn by hand', weekdays: [1, 2, 3, 4, 5, 6]),
      ChoreDefault(title: 'Wash bottles', weekdays: [1, 2, 3, 4, 5, 6]),
    ]);
    final variants = (await repo.loadRoleDefaultSets())
        .where((s) => !s.isBase)
        .toList();
    await repo.activateRoleSet(variants.single);

    final base = await repo.loadBaseRoleDefaultSets();
    expect(base.single.chores.length, 3);
    expect(base.single.chores.map((c) => c.title), contains('Ice the milk'));

    await repo.ensureDayGenerated(friday);
    final instances = await repo.loadInstancesForDate(friday);
    expect(instances.map((i) => i.title), contains('Ice the milk'));
    expect(instances.map((i) => i.title), isNot(contains('Bottle milk')));

    // Switching back restores the original workflow; stale open chores
    // from the variant are cancelled.
    await repo.activateRoleSet(original);
    await repo.syncDayToDefaults(friday);
    final restored = await repo.loadInstancesForDate(friday);
    expect(restored.map((i) => i.title), contains('Bottle milk'));
    final iced = restored.firstWhere((i) => i.title == 'Ice the milk');
    expect(iced.status, ChoreStatus.cancelled);
  });

  test('variant d tags are role:name and round-trip', () async {
    final repo = await seededRepo();
    addTearDown(repo.database.close);

    await repo.saveRoleVariant(FarmRole.pourers, 'Compressor down', const [
      ChoreDefault(title: 'Ice the milk', weekdays: [1, 2, 3, 4, 5, 6]),
    ]);

    final all = await repo.loadRoleDefaultSets();
    final variant = all.singleWhere((s) => !s.isBase);
    expect(variant.name, 'Compressor down');
    expect(variant.role, FarmRole.pourers);
    expect(variant.dTag, 'pourers:Compressor down');
  });

  testWidgets('defaults screen adds a chore and activates a variant', (
    tester,
  ) async {
    final repo = await seededRepo();
    addTearDown(repo.database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: DefaultsScreen(repository: repo, role: FarmRole.pourers),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bottle milk'), findsOneWidget);

    // Add a chore (title + description + checklist are mandatory).
    await tester.tap(find.text('Add chore'));
    await tester.pumpAndSettle();
    // Fill title (first TextField).
    await tester.enterText(find.byType(TextField).first, 'Ice the milk');
    // Fill description (second TextField).
    await tester.enterText(
      find.byType(TextField).at(1),
      'Cool the milk quickly after milking',
    );
    // Fill first checklist item (third TextField).
    await tester.enterText(find.byType(TextField).at(2), 'Check ice level');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Ice the milk'), findsOneWidget);

    // Save the expanded set as a variant.
    await tester.tap(find.text('Save as variant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Compressor down');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Compressor down'), findsOneWidget);

    // Activate it: generation now includes the new chore.
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();
    await repo.ensureDayGenerated(friday);
    final instances = await repo.loadInstancesForDate(friday);
    expect(instances.map((i) => i.title), contains('Ice the milk'));
  });
}
