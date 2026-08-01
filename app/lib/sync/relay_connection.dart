import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// A NIP-01 relay connection: JSON-array frames over a socket.
///
/// Abstract so tests can drive the sync engine without a live relay.
abstract interface class RelayConnection {
  /// Opens the connection; throws when the relay is unreachable.
  Future<void> connect();

  /// Sends one JSON-array frame (EVENT, REQ, CLOSE, ...).
  Future<void> send(List<Object?> message);

  /// Incoming JSON-array frames.
  Stream<List<Object?>> receive();

  Future<void> close();
}

/// WebSocket-backed connection to a FarmChore relay.
class WebSocketRelayConnection implements RelayConnection {
  WebSocketRelayConnection(this.url);

  final String url;
  WebSocketChannel? _channel;

  @override
  Future<void> connect() async {
    final channel = WebSocketChannel.connect(Uri.parse(url));
    await channel.ready;
    _channel = channel;
  }

  @override
  Future<void> send(List<Object?> message) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError('relay is not connected');
    }
    channel.sink.add(jsonEncode(message));
  }

  @override
  Stream<List<Object?>> receive() {
    final channel = _channel;
    if (channel == null) {
      return const Stream.empty();
    }
    return channel.stream.map(
      (frame) => jsonDecode(frame as String) as List<Object?>,
    );
  }

  @override
  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }
}
