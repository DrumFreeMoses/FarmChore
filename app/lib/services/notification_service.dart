import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Bridges the Flutter app to the service worker for background notifications.
///
/// When the app is in the foreground, the live WebSocket subscription handles
/// real-time updates. When backgrounded or closed, the service worker
/// maintains the WebSocket connection and shows browser notifications.
class NotificationService {
  /// Sends relay connection info to the service worker so it can maintain
  /// a background WebSocket connection and show notifications.
  static void connectBackgroundRelay(
    String relayUrl,
    String pubkey, {
    String? apiKey,
  }) {
    final message = <String, dynamic>{
      'type': 'farmchore-relay-connect',
      'relayUrl': relayUrl,
      'pubkey': pubkey,
    };
    if (apiKey != null) message['apiKey'] = apiKey;
    _postToServiceWorker(message.jsify()!);
  }

  /// Tells the service worker to disconnect from the relay.
  static void disconnectBackgroundRelay() {
    _postToServiceWorker({'type': 'farmchore-relay-disconnect'}.jsify()!);
  }

  /// Requests notification permission from the browser.
  /// Returns true if permission was granted.
  static Future<bool> requestPermission() async {
    try {
      final result = await web.Notification.requestPermission().toDart;
      return result.dartify()?.toString() == 'granted';
    } catch (_) {
      return false;
    }
  }

  static void _postToServiceWorker(JSAny message) {
    try {
      final controller = web.window.navigator.serviceWorker.controller;
      if (controller != null) {
        controller.postMessage(message);
      }
    } catch (_) {
      // Service worker not available or not supported.
    }
  }
}
