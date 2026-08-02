import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Displays a QR code that encodes the relay URL and farm pubkey so new
/// members can scan it to join the farm's ChoreChore instance.
class InviteScreen extends StatelessWidget {
  const InviteScreen({
    super.key,
    required this.relayUrl,
    required this.farmPubkey,
    this.farmName = 'Jacob Springs Farm',
  });

  final String relayUrl;
  final String farmPubkey;
  final String farmName;

  /// The data encoded in the QR code: a JSON object with relay and pubkey.
  String get _qrData =>
      jsonEncode({'relay': relayUrl, 'pubkey': farmPubkey, 'name': farmName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite to Farm')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(farmName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Scan this QR code to join',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FarmColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: FarmColors.soilBrown.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: FarmColors.surface,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Relay: $relayUrl',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
