import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/dashboard_screen.dart';
import 'package:farm_chore/screens/role_chores_screen.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:nostr/nostr.dart';

Future<ChoreRepository> seedRepository({Keys? keys, DateTime? today}) async {
  final db = await AppDatabase.openInMemory();
  final repo = ChoreRepository(
    database: db,
    keys: keys ?? Keys.generate(),
    farmPubkey: 'f' * 64,
  );
  await repo.saveRoleDefaultSet(
    const RoleDefaultSet(
      role: FarmRole.milkers,
      chores: [
        ChoreDefault(title: 'Morning milking', weekdays: [1, 2, 3, 4, 5, 6]),
        ChoreDefault(title: 'Clean stalls', weekdays: [1, 2, 3, 4, 5, 6]),
        ChoreDefault(title: 'Evening milking', weekdays: [1, 2, 3, 4, 5, 6]),
      ],
    ),
  );
  await repo.saveRoleDefaultSet(
    const RoleDefaultSet(
      role: FarmRole.feeders,
      chores: [
        ChoreDefault(title: 'Feed calves', weekdays: [1, 2, 3, 4, 5, 6]),
      ],
    ),
  );
  await repo.ensureDayGenerated(today ?? DateTime(2026, 7, 31));
  return repo;
}

void main() {
  final friday = DateTime(2026, 7, 31);

  testWidgets('dashboard shows per-role counts for today', (tester) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: DashboardScreen(repository: repo, today: friday),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Milker's Chores"), findsOneWidget);
    expect(find.text("Feeder's Chores"), findsOneWidget);
    expect(find.text('3 open'), findsOneWidget);
    expect(find.text('0 done'), findsNWidgets(2));
    expect(find.text('No chores today'), findsNWidgets(4));
  });

  testWidgets('tapping a role card drills into its chore list', (tester) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: DashboardScreen(repository: repo, today: friday),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Milker's Chores"));
    await tester.pumpAndSettle();

    expect(find.byType(RoleChoresScreen), findsOneWidget);
    expect(find.text('Morning milking'), findsOneWidget);
    expect(find.text('Clean stalls'), findsOneWidget);
    expect(find.text('Evening milking'), findsOneWidget);
  });

  testWidgets('marking a chore done updates the dashboard count', (
    tester,
  ) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: DashboardScreen(repository: repo, today: friday),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Milker's Chores"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning milking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark done'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('1 done'), findsOneWidget);
    expect(find.text('2 open'), findsOneWidget);
  });
}
