import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/role_default_set.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/my_chores_screen.dart';
import 'package:farm_chore/screens/undone_chores_screen.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:nostr/nostr.dart';

Future<ChoreRepository> seed({
  required String assignee,
  required DateTime today,
  bool withAssignments = true,
}) async {
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
        ChoreDefault(title: 'Clean stalls', weekdays: [1, 2, 3, 4, 5, 6]),
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
  await repo.ensureDayGenerated(today);
  if (withAssignments) {
    for (final instance in await repo.loadInstancesForDate(today)) {
      await repo.assign(instance, assignee);
    }
  }
  return repo;
}

void main() {
  final friday = DateTime(2026, 7, 31);
  final me = 'a' * 64;

  group('MyChoresScreen', () {
    testWidgets('shows only my assigned, remaining instances', (tester) async {
      final repo = await seed(assignee: me, today: friday);
      addTearDown(repo.database.close);

      await repo.editStatus(
        (await repo.loadInstancesForDate(friday)).first,
        ChoreStatus.done,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: MyChoresScreen(repository: repo, myPubkey: me, today: friday),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Morning milking'), findsOneWidget);
      expect(find.text('Feed calves'), findsOneWidget);
      expect(find.text('Clean stalls'), findsNothing); // done
    });

    testWidgets('marks a chore done from the quick sheet', (tester) async {
      final repo = await seed(assignee: me, today: friday);
      addTearDown(repo.database.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: MyChoresScreen(repository: repo, myPubkey: me, today: friday),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Morning milking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();

      expect(find.text('Morning milking'), findsNothing);
      expect(find.text('Feed calves'), findsOneWidget);
    });

    testWidgets('shows an empty state when nothing is assigned', (
      tester,
    ) async {
      final repo = await seed(
        assignee: me,
        today: friday,
        withAssignments: false,
      );
      addTearDown(repo.database.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: MyChoresScreen(repository: repo, myPubkey: me, today: friday),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing assigned to you today.'), findsOneWidget);
    });
  });

  group('UndoneChoresScreen', () {
    testWidgets('groups remaining work by role with counts', (tester) async {
      final repo = await seed(assignee: me, today: friday);
      addTearDown(repo.database.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: UndoneChoresScreen(repository: repo, today: friday),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Milker's Chores"), findsOneWidget);
      expect(find.text("Feeder's Chores"), findsOneWidget);
      expect(find.text('2 remaining'), findsOneWidget);
      expect(find.text('1 remaining'), findsOneWidget);
    });

    testWidgets('done work disappears from the undone list', (tester) async {
      final repo = await seed(assignee: me, today: friday);
      addTearDown(repo.database.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: UndoneChoresScreen(repository: repo, today: friday),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Morning milking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();

      expect(find.text('Morning milking'), findsNothing);
      expect(find.text('1 remaining'), findsNWidgets(2));
    });

    testWidgets('shows the all-done state', (tester) async {
      final repo = await seed(assignee: me, today: friday);
      addTearDown(repo.database.close);

      for (final instance in await repo.loadInstancesForDate(friday)) {
        await repo.editStatus(instance, ChoreStatus.done);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: UndoneChoresScreen(repository: repo, today: friday),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All done for today.'), findsOneWidget);
    });
  });
}
