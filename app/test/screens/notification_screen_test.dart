import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';

void main() {
  late AppDatabase db;
  late Keys keys;
  late ChoreRepository repo;
  final farmPubkey = 'f' * 64;

  setUp(() async {
    db = await AppDatabase.openInMemory();
    keys = Keys.generate();
    repo = ChoreRepository(database: db, keys: keys, farmPubkey: farmPubkey);
  });

  tearDown(() => db.close());

  group('NotificationScreen', () {
    testWidgets('shows empty state when no notifications', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: NotificationScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });

    testWidgets('shows notification after assignment', (tester) async {
      final instance = ChoreInstance(
        date: DateTime(2026, 8, 1),
        role: FarmRole.milkers,
        slug: 'milking-am',
        title: 'Morning milking',
        type: ChoreType.chore,
        status: ChoreStatus.open,
      );
      await repo.saveInstance(instance);
      await repo.assign(instance, keys.public);

      await tester.pumpWidget(
        MaterialApp(home: NotificationScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assigned to you'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('shows heads-up notification', (tester) async {
      await repo.saveHeadsUp('Rain expected this afternoon');

      await tester.pumpWidget(
        MaterialApp(home: NotificationScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Heads up'), findsOneWidget);
      expect(find.text('Rain expected this afternoon'), findsOneWidget);
      expect(find.byIcon(Icons.campaign), findsOneWidget);
    });

    testWidgets('mark all read clears badge count', (tester) async {
      await repo.saveHeadsUp('Test notice');

      await tester.pumpWidget(
        MaterialApp(home: NotificationScreen(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test notice'), findsOneWidget);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(find.text('Mark all read'), findsNothing);
    });
  });
}
