import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/screens/home_shell.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:nostr/nostr.dart';

void main() {
  testWidgets('shell boots and shows the dashboard', (tester) async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = ChoreRepository(database: db, keys: Keys.generate());
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: HomeShell(
          repository: repo,
          myPubkey: 'a' * 64,
          today: DateTime(2026, 7, 31),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FarmChore'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('My Chores'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });
}
