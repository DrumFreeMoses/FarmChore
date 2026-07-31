import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/screens/news_screen.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:nostr/nostr.dart';

void main() {
  test('heads-ups load newest first with scope and author name', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = ChoreRepository(database: db, keys: Keys.generate());
    await repo.saveMyName('Moses');

    await repo.saveHeadsUp('Frost tonight — cover the greens');
    await repo.saveHeadsUp(
      'Compressor down, use the icing workflow',
      scope: FarmRole.pourers,
    );

    final names = await repo.loadMemberNames();
    expect(names[repo.myPubkey], 'Moses');

    final ups = await repo.loadHeadsUps();
    expect(ups.length, 2);
    expect(ups.first.text, 'Compressor down, use the icing workflow');
    expect(ups.first.scope, FarmRole.pourers);
    expect(ups.last.isFarmWide, isTrue);
  });

  testWidgets('news tab shows empty state, then posts a scoped heads-up', (
    tester,
  ) async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = ChoreRepository(database: db, keys: Keys.generate());
    await repo.saveMyName('Moses');

    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: NewsScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No heads-ups yet. Post the first one!'), findsOneWidget);

    await tester.tap(find.byTooltip('Add heads up'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Notice'),
      'Frost tonight — cover the greens',
    );
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(find.text('Frost tonight — cover the greens'), findsOneWidget);
    expect(find.text('Whole farm'), findsOneWidget);
    expect(find.text('— Moses'), findsOneWidget);

    // Scoped notice shows the role group.
    await tester.tap(find.byTooltip('Add heads up'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Notice'),
      'Ice the milk 3x today',
    );
    await tester.tap(find.byType(DropdownButtonFormField<FarmRole?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Pourer's Chores").last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(find.text('Ice the milk 3x today'), findsOneWidget);
    expect(find.text("Pourer's Chores"), findsOneWidget);
  });
}
