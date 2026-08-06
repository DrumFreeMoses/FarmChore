import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:farm_chore/config/relay_config.dart';
import 'package:farm_chore/identity/identity_service.dart';
import 'package:farm_chore/identity/key_storage.dart';
import 'package:farm_chore/theme/farm_theme.dart';

/// Settings screen: shows relay info, key backup/restore, and app info.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.relayConfig,
    required this.relayUrl,
  });

  final RelayConfig relayConfig;
  final String relayUrl;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _nsec;
  bool _showKey = false;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final storage = SecureKeyStorage();
    final nsec = await storage.load();
    if (mounted) setState(() => _nsec = nsec);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Relay ──────────────────────────────────────────
          _sectionHeader(context, 'Relay'),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Connected relay'),
            subtitle: Text(widget.relayUrl),
          ),
          if (widget.relayConfig.apiKey != null)
            ListTile(
              leading: const Icon(Icons.vpn_key),
              title: const Text('API key'),
              subtitle: Text(
                _showApiKey ? widget.relayConfig.apiKey! : 'Tap to reveal',
              ),
              onTap: () => setState(() => _showApiKey = !_showApiKey),
            ),

          // ── Identity ──────────────────────────────────────
          _sectionHeader(context, 'Identity'),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('Your secret key'),
            subtitle: Text(
              _showKey ? (_nsec ?? 'Loading...') : 'Tap to reveal',
            ),
            onTap: () => setState(() => _showKey = !_showKey),
            trailing: _nsec != null
                ? IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy to clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _nsec!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Secret key copied to clipboard'),
                        ),
                      );
                    },
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: FarmColors.error.withAlpha(25),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: FarmColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Write this key down and store it somewhere safe. '
                        'If you lose this key, you lose your identity on the farm. '
                        'Anyone with this key can impersonate you.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Restore from secret key'),
            subtitle: const Text('Import a previously backed-up identity'),
            onTap: _restoreIdentity,
          ),

          // ── About ──────────────────────────────────────────
          _sectionHeader(context, 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('FarmChore'),
            subtitle: Text('Chore management for Jacob Springs Farm'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: FarmColors.cottonwoodGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _restoreIdentity() async {
    final controller = TextEditingController();
    final secret = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore identity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your nsec1... secret key or 64-char hex key.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Secret key',
                hintText: 'nsec1...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (secret == null || secret.isEmpty || !mounted) return;

    try {
      final identity = await IdentityService(
        SecureKeyStorage(),
      ).importIdentity(secret);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Identity restored: ${identity.npub}')),
        );
        setState(() {
          _nsec = secret;
          _showKey = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid key: $e')));
      }
    }
  }
}
