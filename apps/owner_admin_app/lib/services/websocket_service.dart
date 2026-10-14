import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    try {
      final uri = Uri.parse(ApiConfig.wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data.toString());
            _eventController.add(parsed);
          } catch (e) {
            debugPrint('[WS] Decode error: $e');
          }
        },
        onError: (err) {
          debugPrint('[WS] Error: $err');
          _reconnect();
        },
        onDone: () {
          debugPrint('[WS] Connection closed');
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('[WS] Connect error: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      connect();
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
