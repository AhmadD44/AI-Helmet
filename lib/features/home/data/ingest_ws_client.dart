import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class IngestWsClient {
  final Uri ingestUri;
  final bool debugLog;

  WebSocketChannel? _channel;
  bool _isConnecting = false;
  bool _isConnected = false;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);

  IngestWsClient({
    required this.ingestUri,
    this.debugLog = true,
  });

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    
    _isConnecting = true;
    
    try {
      if (debugLog) {
        print('🌐 Connecting to WebSocket: $ingestUri');
      }
      
      _channel = WebSocketChannel.connect(ingestUri);
      
      _channel!.stream.listen(
        (_) {}, 
        onError: (error) {
          if (debugLog) {
            print('❌ WebSocket error: $error');
          }
          _handleDisconnection();
        },
        onDone: () {
          if (debugLog) {
            print('🔌 WebSocket disconnected');
          }
          _handleDisconnection();
        },
      );
      
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0; 
      
      if (debugLog) {
        print('✅ WebSocket connected');
      }
      
    } catch (e) {
      _isConnecting = false;
      if (debugLog) {
        print('❌ WebSocket connection failed: $e');
      }
      _scheduleReconnect();
    }
  }

  Future<void> send(Map<String, dynamic> payload) async {
    if (!_isConnected) {
      await connect();
    }
    
    if (_channel == null || !_isConnected) {
      if (debugLog) {
        print('⚠️ WebSocket not ready, skipping send');
      }
      return;
    }
    
    try {
      final jsonString = jsonEncode(payload);
      
      if (debugLog) {
        print('📤 Sending to WebSocket: ${jsonString.length} bytes');
        if (jsonString.length > 100) {
          print('📋 Data preview: ${jsonString.substring(0, 100)}...');
        }
      }
      
      _channel!.sink.add(jsonString);
      
    } catch (e) {
      if (debugLog) {
        print('❌ WebSocket send error: $e');
      }
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null || _reconnectAttempts >= maxReconnectAttempts) {
      return;
    }
    
    _reconnectAttempts++;
    
    if (debugLog) {
      print('🔄 Scheduling reconnect in ${reconnectDelay.inSeconds}s '
          '(attempt $_reconnectAttempts/$maxReconnectAttempts)');
    }
    
    _reconnectTimer = Timer(reconnectDelay, () async {
      _reconnectTimer = null;
      if (!_isConnected && _reconnectAttempts <= maxReconnectAttempts) {
        await connect();
      }
    });
  }

  Future<void> close() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    try {
      if (_channel != null) {
        await _channel!.sink.close(status.goingAway);
      }
    } catch (e) {
      if (debugLog) {
        print('⚠️ Error closing WebSocket: $e');
      }
    }
    
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    
    if (debugLog) {
      print('👋 WebSocket closed');
    }
  }
}