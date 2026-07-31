import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_chore/domain/chore_instance.dart';
import 'package:farm_chore/domain/roles.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:farm_chore/widgets/chore_card.dart';

Widget wrap(Widget child) => MaterialApp(theme: farmTheme(), home: child);

ChoreInstance instance({
  ChoreType type = ChoreType.chore,
  ChoreStatus status = ChoreStatus.open,
  String? assignee,
}) => ChoreInstance(
  date: DateTime(2026, 7, 31),
  role: FarmRole.milkers,
  slug: 'morning-milking',
  title: 'Morning milking',
  type: type,
  status: status,
  assignee: assignee,
);

void main() {
  testWidgets('chore card is amber filled with a square badge', (tester) async {
    await tester.pumpWidget(wrap(ChoreCard(instance: instance())));
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.elevation, 2);
    expect(card.shape, isA<RoundedRectangleBorder>());
    final badge = tester.widget<Container>(find.byType(Container).first);
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, FarmColors.dawnAmber);
    expect(decoration.borderRadius, BorderRadius.zero);
  });

  testWidgets('task card is outlined in spring blue with a rounded badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ChoreCard(instance: instance(type: ChoreType.task))),
    );
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.elevation, 0);
    final shape = card.shape! as RoundedRectangleBorder;
    expect(shape.side.color, FarmColors.springBlue);
    final badge = tester.widget<Container>(find.byType(Container).first);
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, FarmColors.springBlue);
    expect(decoration.borderRadius, isNot(BorderRadius.zero));
  });

  testWidgets('shows title and assignee', (tester) async {
    await tester.pumpWidget(
      wrap(ChoreCard(instance: instance(assignee: 'Sana'))),
    );
    expect(find.text('Morning milking'), findsOneWidget);
    expect(find.text('Assigned: Sana'), findsOneWidget);
  });

  testWidgets('done status strikes through and shows a green Done chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(ChoreCard(instance: instance(status: ChoreStatus.done))),
    );
    expect(find.text('Done'), findsOneWidget);
    final chip = tester.widget<Container>(
      find
          .byWidgetPredicate(
            (w) =>
                w is Container &&
                (w.decoration as BoxDecoration?)?.color ==
                    FarmColors.cottonwoodGreen,
          )
          .first,
    );
    expect(chip, isNotNull);
  });

  testWidgets('open status shows no chip', (tester) async {
    await tester.pumpWidget(wrap(ChoreCard(instance: instance())));
    expect(find.text('Done'), findsNothing);
    expect(find.text('Skipped'), findsNothing);
  });

  testWidgets('deferred shows a blue arrow chip', (tester) async {
    await tester.pumpWidget(
      wrap(ChoreCard(instance: instance(status: ChoreStatus.deferred))),
    );
    expect(find.text('Deferred'), findsOneWidget);
  });

  testWidgets('tap fires callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(ChoreCard(instance: instance(), onTap: () => tapped = true)),
    );
    await tester.tap(find.text('Morning milking'));
    expect(tapped, isTrue);
  });
}
