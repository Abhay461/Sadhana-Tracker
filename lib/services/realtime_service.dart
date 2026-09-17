import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class RealtimeEvent {
  final String type; // 'sadhana_update', 'accommodation_update', 'appointment_update', 'student_update', 'trip_update', 'event_update', 'announcement_update', 'payment_update'
  final String action; // 'create', 'update', 'delete', 'register', 'profile_update'
  final Map<String, dynamic> data;
  final String? preacherId;
  final String? studentId;
  final String timestamp;

  RealtimeEvent({
    required this.type,
    required this.action,
    required this.data,
    this.preacherId,
    this.studentId,
    required this.timestamp,
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    dynamic rawData = json['data'];
    Map<String, dynamic> dataMap = {};
    if (rawData is Map) {
      dataMap = Map<String, dynamic>.from(rawData);
    } else if (rawData != null) {
      dataMap = {'value': rawData};
    }

    return RealtimeEvent(
      type: (json['event'] ?? json['type'] ?? 'unknown').toString(),
      action: (json['action'] ?? 'update').toString(),
      data: dataMap,
      preacherId: json['preacherId']?.toString(),
      studentId: json['studentId']?.toString(),
      timestamp: (json['timestamp'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }
}

class RealtimeService {
  RealtimeService._internal();
  static final RealtimeService instance = RealtimeService._internal();

  WebSocket? _socket;
  final StreamController<RealtimeEvent> _eventController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get eventStream => _eventController.stream;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _disposed = false;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;

  String _getWebSocketUrl() {
    final baseUrl = ApiService.baseUrl;
    String wsUrl = baseUrl;

    if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    }

    // Strip trailing /api/v1 if present to target /ws endpoint
    if (wsUrl.endsWith('/api/v1')) {
      wsUrl = wsUrl.substring(0, wsUrl.length - 7);
    } else if (wsUrl.endsWith('/api/v1/')) {
      wsUrl = wsUrl.substring(0, wsUrl.length - 8);
    }

    if (wsUrl.endsWith('/')) {
      wsUrl = '${wsUrl}ws';
    } else {
      wsUrl = '$wsUrl/ws';
    }

    return wsUrl;
  }

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _disposed = false;
    _isConnecting = true;

    final url = _getWebSocketUrl();
    debugPrint('⚡ [REALTIME] Connecting to WebSocket: $url');

    try {
      _socket = await WebSocket.connect(url).timeout(const Duration(seconds: 10));
      _isConnected = true;
      _isConnecting = false;
      debugPrint('⚡ [REALTIME] Connected successfully to WebSocket');

      // Start ping heartbeat
      _startPingHeartbeat();

      // Listen to incoming messages
      _socket!.listen(
        (data) {
          _handleIncomingData(data);
        },
        onDone: () {
          debugPrint('⚡ [REALTIME] WebSocket connection closed by server');
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint('⚡ [REALTIME] WebSocket error: $error');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      debugPrint('⚡ [REALTIME] Failed to connect to WebSocket: $e');
      _scheduleReconnect();
    }
  }

  void _handleIncomingData(dynamic data) {
    if (data is String) {
      if (data == 'pong') return;
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map<String, dynamic>) {
          final event = RealtimeEvent.fromJson(parsed);
          debugPrint('[REALTIME] Event received: ${event.type}:${event.action}');
          _eventController.add(event);
        }
      } catch (e) {
        debugPrint('⚡ [REALTIME] Error parsing WebSocket message: $e');
      }
    }
  }

  void _startPingHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected && _socket != null) {
        try {
          _socket!.add('ping');
        } catch (_) {}
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _pingTimer?.cancel();
    _socket = null;
    if (!_disposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && !_isConnecting && !_disposed) {
        debugPrint('⚡ [REALTIME] Attempting auto-reconnect...');
        connect();
      }
    });
  }

  void disconnect() {
    _disposed = true;
    _isConnected = false;
    _isConnecting = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    debugPrint('⚡ [REALTIME] Disconnected cleanly');
  }
}
