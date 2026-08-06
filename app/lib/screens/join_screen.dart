import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:farm_chore/config/relay_config.dart';
import 'package:farm_chore/theme/farm_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Screen that scans a QR code to join a farm's relay.
///
/// The QR encodes JSON: `{"relay": "wss://...", "key": "...", "name": "Farm Name"}`.
/// On successful scan the relay URL and API key are saved.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.relayConfig});

  final RelayConfig relayConfig;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  bool _scanned = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a Farm')),
      body: Column(
        children: [
          Expanded(flex: 3, child: MobileScanner(onDetect: _onDetect)),
          Expanded(
            flex: 2,
            child: Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: FarmColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() {
                              _error = null;
                              _scanned = false;
                            }),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: FarmColors.sabbath,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Point your camera at the farm\'s QR code',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ask the farm owner to show you the invite QR',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    try {
      final data = jsonDecode(barcode.rawValue!) as Map<String, dynamic>;
      final relay = data['relay'] as String?;
      if (relay == null || relay.isEmpty) {
        throw FormatException('QR missing relay URL');
      }
      if (!relay.startsWith('ws://') && !relay.startsWith('wss://')) {
        throw FormatException('Relay URL must start with ws:// or wss://');
      }

      final key = data['key'] as String?;

      setState(() => _scanned = true);

      widget.relayConfig.configure(url: relay, apiKey: key).then((_) {
        if (mounted) {
          Navigator.of(context).pop(relay);
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Invalid QR code. Expected a FarmChore invite code.';
      });
    }
  }
}
