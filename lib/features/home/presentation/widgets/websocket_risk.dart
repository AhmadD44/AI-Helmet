// web_socket_risk_listener.dart - Updated version

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

class WebSocketRiskListener {
  final Uri ingestUri; // Use the SAME WebSocket as telemetry
  final Function(RiskData) onRiskStatus;
  final Function(String) onError;
  
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 10;
  
  WebSocketRiskListener({
    required this.ingestUri,
    required this.onRiskStatus,
    required this.onError,
  });
  
  Future<void> connect() async {
    if (_isConnected) return;
    
    try {
      print('🌐 Connecting to Risk WebSocket: $ingestUri');
      _channel = WebSocketChannel.connect(ingestUri);
      
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          print('❌ Risk WebSocket error: $error');
          onError('WebSocket error: $error');
          _handleDisconnection();
        },
        onDone: () {
          print('🔌 Risk WebSocket disconnected');
          _handleDisconnection();
        },
      );
      
      _isConnected = true;
      _reconnectAttempts = 0;
      print('✅ Risk WebSocket connected successfully');
      
    } catch (e) {
      print('❌ Risk WebSocket connection failed: $e');
      onError('Connection failed: $e');
      _scheduleReconnect();
    }
  }
  
  void _handleMessage(dynamic message) {
    try {
      print('📥 WebSocket raw message: ${message.toString().substring(0, min(100, message.toString().length))}...');
      
      if (message is String) {
        final data = jsonDecode(message);
        
        // Check if this is a RISK_STATUS message
        if (data['type'] == 'RISK_STATUS') {
          print('🎯 RISK_STATUS received from WebSocket!');
          print('   Full data: $data');
          
          final riskPayload = data['payload'];
          if (riskPayload != null && riskPayload is Map<String, dynamic>) {
            try {
              final riskData = RiskData.fromJson(riskPayload);
              print('   ✅ Parsed Risk: ${riskData.level} (${riskData.score})');
              print('   Reasons: ${riskData.reasons}');
              print('   Speed: ${riskData.speedKmh} km/h');
              
              // Pass to callback
              onRiskStatus(riskData);
            } catch (e) {
              print('❌ Error parsing risk data: $e');
            }
          } else {
            print('❌ No payload in RISK_STATUS message');
          }
        } else {
          print('📊 Other message type: ${data['type']}');
        }
      }
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }
  
  int min(int a, int b) => a < b ? a : b;
  
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
    
    print('🔄 Scheduling WebSocket reconnect in 5s '
        '(attempt $_reconnectAttempts/$maxReconnectAttempts)');
    
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (!_isConnected && _reconnectAttempts <= maxReconnectAttempts) {
        connect();
      }
    });
  }
  
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    try {
      await _channel?.sink.close();
    } catch (e) {
      print('⚠️ Error closing WebSocket: $e');
    }
    
    _channel = null;
    _isConnected = false;
    
    print('👋 WebSocket closed');
  }
  
  bool get isConnected => _isConnected;
}