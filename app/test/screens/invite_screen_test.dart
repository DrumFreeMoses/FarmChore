import 'package:farm_chore/screens/invite_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  const fakePubkey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  group('InviteScreen', () {
    testWidgets('displays farm name and QR code', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InviteScreen(
            relayUrl: 'ws://localhost:7447',
            farmPubkey: fakePubkey,
            farmName: 'Test Farm',
          ),
        ),
      );

      expect(find.text('Test Farm'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Scan this QR code to join'), findsOneWidget);
      expect(find.text('Relay: ws://localhost:7447'), findsOneWidget);
    });

    testWidgets('displays relay URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InviteScreen(
            relayUrl: 'wss://relay.farm.example',
            farmPubkey: fakePubkey,
          ),
        ),
      );

      expect(find.text('Relay: wss://relay.farm.example'), findsOneWidget);
    });
  });
}
