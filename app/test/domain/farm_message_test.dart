import 'package:farm_chore/data/app_database.dart';
import 'package:farm_chore/data/chore_repository.dart';
import 'package:farm_chore/domain/farm_message.dart';
import 'package:farm_chore/screens/message_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';

void main() {
  late AppDatabase db;
  late Keys keys;
  late ChoreRepository repo;

  setUp(() async {
    db = await AppDatabase.openInMemory();
    keys = Keys.generate();
    repo = ChoreRepository(database: db, keys: keys);
  });

  tearDown(() => db.close());

  group('FarmMessage model', () {
    test('broadcast message has no recipient', () {
      const msg = FarmMessage(
        text: 'Hello farm!',
        author: 'key123',
        createdAt: 1700000000,
      );

      expect(msg.isBroadcast, isTrue);
      expect(msg.isDirect, isFalse);
      expect(msg.recipient, isNull);
    });

    test('DM has recipient', () {
      const msg = FarmMessage(
        text: 'Hey there',
        author: 'key123',
        createdAt: 1700000000,
        recipient: 'key456',
      );

      expect(msg.isDirect, isTrue);
      expect(msg.isBroadcast, isFalse);
      expect(msg.recipient, 'key456');
    });

    test('conversationWith returns farm for broadcast', () {
      const msg = FarmMessage(
        text: 'Hello',
        author: 'key123',
        createdAt: 1700000000,
      );

      expect(msg.conversationWith('key999'), 'farm');
    });

    test('conversationWith returns author for incoming DM', () {
      const msg = FarmMessage(
        text: 'Hey',
        author: 'key123',
        createdAt: 1700000000,
        recipient: 'key999',
      );

      expect(msg.conversationWith('key999'), 'key123');
    });

    test('conversationWith returns recipient for outgoing DM', () {
      const msg = FarmMessage(
        text: 'Hey',
        author: 'key999',
        createdAt: 1700000000,
        recipient: 'key123',
      );

      expect(msg.conversationWith('key999'), 'key123');
    });

    test('roundtrips through Nostr event', () {
      const msg = FarmMessage(
        text: 'Hello farm!',
        author: 'key123',
        createdAt: 1700000000,
        recipient: 'key456',
      );

      final event = msg.toNostrEvent(pubKey: 'key123', createdAt: 1700000000);
      final parsed = FarmMessage.fromNostrEvent(event);

      expect(parsed.text, 'Hello farm!');
      expect(parsed.author, 'key123');
      expect(parsed.recipient, 'key456');
    });

    test('roundtrips broadcast message', () {
      const msg = FarmMessage(
        text: 'Farm update',
        author: 'key123',
        createdAt: 1700000000,
      );

      final event = msg.toNostrEvent(pubKey: 'key123', createdAt: 1700000000);
      final parsed = FarmMessage.fromNostrEvent(event);

      expect(parsed.text, 'Farm update');
      expect(parsed.isBroadcast, isTrue);
    });
  });

  group('ChoreRepository messages', () {
    test('sendMessage persists broadcast', () async {
      await repo.sendMessage('Hello farm!');

      final messages = await repo.loadMessages();
      expect(messages.length, 1);
      expect(messages.first.text, 'Hello farm!');
      expect(messages.first.isBroadcast, isTrue);
    });

    test('sendMessage persists DM', () async {
      await repo.sendMessage('Hey there', recipient: 'key456');

      final messages = await repo.loadMessages();
      expect(messages.length, 1);
      expect(messages.first.isDirect, isTrue);
      expect(messages.first.recipient, 'key456');
    });

    test('loadMessages returns all messages sorted by time', () async {
      await repo.sendMessage('First');
      await repo.sendMessage('Second');
      await repo.sendMessage('Third');

      final messages = await repo.loadMessages();
      expect(messages.length, 3);
      expect(messages.first.text, 'First');
      expect(messages.last.text, 'Third');
    });
  });

  group('MessageScreen widget', () {
    testWidgets('shows empty state when no messages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MessageScreen(repository: repo, myPubkey: keys.public),
        ),
      );
      await tester.pump();

      expect(find.text('No messages yet. Say hello!'), findsOneWidget);
    });

    testWidgets('shows farm-wide in inbox', (tester) async {
      await repo.sendMessage('Farm update');

      await tester.pumpWidget(
        MaterialApp(
          home: MessageScreen(repository: repo, myPubkey: keys.public),
        ),
      );
      await tester.pump();

      expect(find.text('Farm-wide'), findsOneWidget);
      expect(find.text('Farm update'), findsOneWidget);
    });
  });
}
