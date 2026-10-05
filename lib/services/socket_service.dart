import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/api_service.dart';
import '../utils/api_config.dart';

class SocketService {
  static final SocketService instance = SocketService._internal();

  SocketService._internal();

  io.Socket? _socket;
  final _queueUpdateController = StreamController<int>.broadcast();

  Stream<int> get onQueueUpdated => _queueUpdateController.stream;

  void connect() {
    if (_socket != null && _socket!.connected) return;

    final token = ApiService.authToken;
    if (token == null) return; // Do not connect without JWT

    // Ensure URL is parsed correctly (removes /api suffix if present)
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket']) // for Flutter or Web
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket!.onConnectError((err) => debugPrint('Socket error: $err'));
    _socket!.onError((err) => debugPrint('Socket error: $err'));

    _socket!.on('queue:updated', (data) {
      if (data != null && data['serviceId'] != null) {
        final int serviceId = data['serviceId'];
        _queueUpdateController.add(serviceId);
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void joinServiceRoom(int serviceId) {
    if (_socket?.connected ?? false) {
      _socket!.emit('join_service', serviceId);
    }
  }

  void leaveServiceRoom(int serviceId) {
    if (_socket?.connected ?? false) {
      _socket!.emit('leave_service', serviceId);
    }
  }
}
