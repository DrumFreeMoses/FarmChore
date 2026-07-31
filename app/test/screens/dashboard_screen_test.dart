import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
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

  Future<void> pumpDashboard(
    WidgetTester tester,
    ChoreRepository repo, {
    DateTime? today,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: DashboardScreen(repository: repo, today: today ?? friday),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard shows per-role counts for today', (tester) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await pumpDashboard(tester, repo);
    await tester.tap(find.byTooltip('Show list'));
    await tester.pumpAndSettle();

    expect(find.text("Milker's Chores"), findsOneWidget);
    expect(find.text("Feeder's Chores"), findsOneWidget);
    expect(find.text('3 open'), findsOneWidget);
    expect(find.text('0 done'), findsNWidgets(2));
    expect(find.text('No chores today'), findsNWidgets(4));
    expect(find.text('Morning milking'), findsOneWidget);
  });

  testWidgets('tapping a role card drills into its chore list', (tester) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await pumpDashboard(tester, repo);

    await tester.tap(find.text("Milker's Chores"));
    await tester.pumpAndSettle();

    expect(find.byType(RoleChoresScreen), findsOneWidget);
    expect(find.text('Morning milking'), findsOneWidget);
    expect(find.text('Clean stalls'), findsOneWidget);
    expect(find.text('Evening milking'), findsOneWidget);
  });

  testWidgets('dashboard defaults to grid, toggles to list and back', (
    tester,
  ) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await pumpDashboard(tester, repo);

    // Grid is the default view and lists every chore two-up.
    expect(find.byTooltip('Show list'), findsOneWidget);
    expect(find.text('Morning milking'), findsOneWidget);
    expect(find.text('Clean stalls'), findsOneWidget);
    expect(find.text('3 open'), findsOneWidget);

    await tester.tap(find.byTooltip('Show list'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Show grid'), findsOneWidget);
    expect(find.text('Morning milking'), findsOneWidget);

    await tester.tap(find.byTooltip('Show grid'));
    await tester.pumpAndSettle();

    expect(find.text('Morning milking'), findsOneWidget);
  });

  testWidgets('done chores are listed last within their role', (tester) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    final milking = (await repo.loadInstancesForDate(
      friday,
    )).firstWhere((i) => i.title == 'Clean stalls');
    await repo.editStatus(milking, ChoreStatus.done);
    await pumpDashboard(tester, repo);

    final cleanY = tester.getTopLeft(find.text('Clean stalls')).dy;
    final morningY = tester.getTopLeft(find.text('Morning milking')).dy;
    final eveningY = tester.getTopLeft(find.text('Evening milking')).dy;
    expect(cleanY, greaterThan(morningY));
    expect(cleanY, greaterThan(eveningY));
  });

  testWidgets('saving your name shows it on assignments', (tester) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    final instance = (await repo.loadInstancesForDate(friday)).first;
    await repo.assign(instance, repo.myPubkey);
    await pumpDashboard(tester, repo);

    await tester.tap(find.byTooltip('Your name'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'First name'),
      'Moses',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Assigned: Moses'), findsOneWidget);
    expect(await repo.loadMemberNames(), {repo.myPubkey: 'Moses'});
  });

  testWidgets('adding a one-time task shows it on today\'s dashboard', (
    tester,
  ) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await pumpDashboard(tester, repo);

    await tester.tap(find.byTooltip('New chore or task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What needs doing?'),
      'Fix the gate latch',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Fix the gate latch'), findsOneWidget);
    final tasks = await repo.loadInstancesForDate(friday);
    final task = tasks.firstWhere((i) => i.title == 'Fix the gate latch');
    expect(task.type, ChoreType.task);
  });

  testWidgets('new dialog can add a chore to defaults and assign to me', (
    tester,
  ) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await pumpDashboard(tester, repo);

    await tester.tap(find.byTooltip('New chore or task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What needs doing?'),
      'Ice the milk',
    );
    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to role defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Instance exists today, assigned to me, and repeats in the defaults.
    final instances = await repo.loadInstancesForDate(friday);
    final ice = instances.firstWhere((i) => i.title == 'Ice the milk');
    expect(ice.assignee, repo.myPubkey);
    final base = await repo.loadBaseRoleDefaultSets();
    final milkers = base.singleWhere((s) => s.role == FarmRole.milkers);
    expect(milkers.chores.map((c) => c.title), contains('Ice the milk'));
  });

  testWidgets('marking a chore done updates the dashboard count', (
    tester,
  ) async {
    final repo = await seedRepository(today: friday);
    addTearDown(repo.database.close);
    await pumpDashboard(tester, repo);

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
