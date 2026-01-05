import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:isd/core/errors/flutter_bl_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:isd/features/home/data/esp_classic_bt_msgpack_source.dart';
import 'package:isd/features/home/data/ingest_ws_client.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TelemetryState extends Equatable {
  final bool loading;
  final String? error;
  final Telemetry? data;
  final bool connected;
  final bool wsConnected;
  final int packetsSent;
  final String? connectionStatus;
  final RiskData? currentRisk;
  final bool riskWsConnected;

  const TelemetryState({
    this.loading = false,
    this.error,
    this.data,
    this.connected = false,
    this.wsConnected = false,
    this.packetsSent = 0,
    this.connectionStatus,
    this.currentRisk,
    this.riskWsConnected = false,
  });

  TelemetryState copyWith({
    bool? loading,
    String? error,
    Telemetry? data,
    bool? connected,
    bool? wsConnected,
    int? packetsSent,
    String? connectionStatus,
    RiskData? currentRisk,
    bool? riskWsConnected,
  }) {
    return TelemetryState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
      data: data ?? this.data,
      connected: connected ?? this.connected,
      wsConnected: wsConnected ?? this.wsConnected,
      packetsSent: packetsSent ?? this.packetsSent,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      currentRisk: currentRisk ?? this.currentRisk,
      riskWsConnected: riskWsConnected ?? this.riskWsConnected,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        data,
        connected,
        wsConnected,
        packetsSent,
        connectionStatus,
        currentRisk,
        riskWsConnected,
      ];
}

class TelemetryCubit extends Cubit<TelemetryState> {
  final EspBtClassicSource source;
  final IngestWsClient ingest;
  
  WebSocketChannel? _riskWebSocket;
  StreamSubscription? _riskWebSocketSubscription;

  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _starting = false;
  String? _mac;
  int _packetsSent = 0;
  
  final _jsonBufferHelper = JsonBufferHelper();

  final userForJwt = FirebaseAuth.instance.currentUser;
          

  Timer? _healthTimer;
  DateTime? _lastDataTime;
  static const Duration healthCheckInterval = Duration(seconds: 5);
  static const Duration dataTimeout = Duration(seconds: 15);

  TelemetryCubit({required this.source, required this.ingest})
      : super(const TelemetryState()) {
    _connectToRiskWebSocket();
  }

  Future<void> _connectToRiskWebSocket() async {
    try {
      final token = await userForJwt?.getIdToken();
      print('🌐 Connecting to Risk WebSocket...');
      
      final riskWsUri = Uri(
      scheme: 'ws',
      host: '3.14.15.242',
      port: 8000,
      path: '/ws/stream',
      queryParameters: {'token': token},
    );
      
      _riskWebSocket = WebSocketChannel.connect(riskWsUri);
      
      _riskWebSocketSubscription = _riskWebSocket!.stream.listen(
        (message) {
          _handleRiskWebSocketMessage(message);
        },
        onError: (error) {
          print('❌ Risk WebSocket error: $error');
          emit(state.copyWith(riskWsConnected: false));
          _reconnectRiskWebSocket();
        },
        onDone: () {
          print('🔌 Risk WebSocket disconnected');
          emit(state.copyWith(riskWsConnected: false));
          _reconnectRiskWebSocket();
        },
      );
      
      emit(state.copyWith(riskWsConnected: true));
      print('✅ Risk WebSocket connected');
      
    } catch (e) {
      print('❌ Failed to connect to Risk WebSocket: $e');
      emit(state.copyWith(riskWsConnected: false));
      _reconnectRiskWebSocket();
    }
  }

  void _handleRiskWebSocketMessage(dynamic message) {
    try {
      print('📥 Risk WebSocket message: $message');
      
      if (message is String) {
        final data = jsonDecode(message);
        
        if (data['type'] == 'RISK_STATUS') {
          print('🎯 RISK_STATUS received from WebSocket!');
          
          final riskPayload = data['payload'];
          if (riskPayload != null && riskPayload is Map<String, dynamic>) {
            try {
              final riskData = RiskData.fromJson(riskPayload);
              print('   ✅ Risk parsed: ${riskData.level} (${riskData.score})');
              
              emit(state.copyWith(
                currentRisk: riskData,
              ));
              
            } catch (e) {
              print('❌ Error parsing risk data: $e');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error handling Risk WebSocket message: $e');
    }
  }

  void _reconnectRiskWebSocket() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_riskWebSocket == null || !state.riskWsConnected) {
        print('🔄 Reconnecting to Risk WebSocket...');
        _connectToRiskWebSocket();
      }
    });
  }

  Future<void> startWithMac(String mac) async {
    if (_starting) return;
    _starting = true;
    _mac = mac;
    _jsonBufferHelper.clear();
    
    emit(TelemetryState(
      loading: true,
      data: state.data,
      currentRisk: state.currentRisk,
      riskWsConnected: state.riskWsConnected,
      error: null,
      connected: false,
      connectionStatus: "Checking permissions...",
    ));
    
    final hasPermissions = await _checkBluetoothPermissions();
    if (!hasPermissions) {
      emit(TelemetryState(
        loading: false,
        error: "Bluetooth permissions required.",
        data: state.data,
        currentRisk: state.currentRisk,
        riskWsConnected: state.riskWsConnected,
        connected: false,
        connectionStatus: "Permissions needed",
      ));
      _starting = false;
      return;
    }

    bool connected = false;
    int retryCount = 0;
    const int maxRetries = 2;
    
    while (!connected && retryCount < maxRetries) {
      try {
        emit(state.copyWith(
          connectionStatus: retryCount == 0 
              ? "Connecting to device..." 
              : "Retrying connection... (${retryCount + 1}/$maxRetries)",
        ));

        _connectWebSocketInBackground();

        await source.connect(mac).timeout(const Duration(seconds: 15));
        
        emit(state.copyWith(
          connectionStatus: "Setting up connection...",
        ));
        
        await _setupStreamListener();
        
        _startHealthMonitoring();
        
        connected = true;
        emit(TelemetryState(
          loading: false,
          error: null,
          data: state.data,
          currentRisk: state.currentRisk,
          riskWsConnected: state.riskWsConnected,
          connected: true,
          wsConnected: state.wsConnected,
          connectionStatus: "Connected",
        ));
        
      } on TimeoutException {
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        emit(TelemetryState(
          loading: false,
          error: "Connection timeout.",
          data: state.data,
          currentRisk: state.currentRisk,
          riskWsConnected: state.riskWsConnected,
          connected: false,
          connectionStatus: "Timeout",
        ));
        _scheduleReconnect();
        
      } on Exception catch (e) {
        retryCount++;
        
        final errorMessage = _parseConnectionError(e);
        
        if (retryCount < maxRetries) {
          print("⚠️ Connection failed, retrying... ($retryCount/$maxRetries)");
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        emit(TelemetryState(
          loading: false,
          error: errorMessage,
          data: state.data,
          currentRisk: state.currentRisk,
          riskWsConnected: state.riskWsConnected,
          connected: false,
          connectionStatus: "Failed",
        ));
        
        if (!errorMessage.contains("paired") && 
            !errorMessage.contains("permission") &&
            !errorMessage.contains("not found")) {
          _scheduleReconnect();
        }
      }
    }
    
    _starting = false;
  }

  String _parseConnectionError(Exception e) {
    final errorStr = e.toString();
    
    if (errorStr.contains("connection_failed") || errorStr.contains("could not connect")) {
      return "Failed to connect to device.";
    }
    
    if (errorStr.contains("bluetooth_disabled")) {
      return "Bluetooth is disabled.";
    }
    
    if (errorStr.contains("permission") || errorStr.contains("denied")) {
      return "Bluetooth permission denied.";
    }
    
    if (errorStr.contains("device_not_found") || errorStr.contains("not found")) {
      return "Device not found.";
    }
    
    if (errorStr.contains("already_connected")) {
      return "Already connected to this device.";
    }
    
    return "Connection failed.";
  }

  Future<bool> _checkBluetoothPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final permissions = await [
          Permission.locationWhenInUse,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        
        return permissions[Permission.locationWhenInUse]?.isGranted == true &&
               permissions[Permission.bluetoothScan]?.isGranted == true &&
               permissions[Permission.bluetoothConnect]?.isGranted == true;
      } catch (e) {
        print('⚠️ Permission check error: $e');
        return false;
      }
    }
    return true;
  }

  Future<void> _setupStreamListener() async {
    await _sub?.cancel();

    _sub = source.stream.listen(
      (payload) async {
        _lastDataTime = DateTime.now();
        
        Telemetry? telemetry;
        
        if (payload is String) {
          telemetry = _parseTelemetryFromString(payload as String);
        } else if (payload is Map<String, dynamic>) {
          telemetry = _parseTelemetryFromMap(payload);
          
          _sendToWebSocket(payload);
        }
        
        if (telemetry != null) {
          emit(state.copyWith(
            data: telemetry,
            error: null,
            connected: true,
            connectionStatus: "Receiving data",
          ));
        }
      },
      onError: (error) {
        print("❌ Telemetry stream error: $error");
        _handleStreamError(error);
      },
      onDone: () {
        print("ℹ️ Telemetry stream closed");
        _handleStreamClosed();
      },
    );
  }

  Telemetry? _parseTelemetryFromString(String rawData) {
    try {
      String cleanedData = rawData
          .replaceAll('\x00', '')
          .replaceAll('\r', '')
          .trim();
      
      if (!cleanedData.startsWith('{')) {
        int jsonStart = cleanedData.indexOf('{');
        if (jsonStart != -1) {
          cleanedData = cleanedData.substring(jsonStart);
        }
      }
      
      _jsonBufferHelper.addChunk(cleanedData);
      final completeJsons = _jsonBufferHelper.extractCompleteJsons();
      
      if (completeJsons.isNotEmpty) {
        Telemetry? latestTelemetry;
        
        for (final jsonData in completeJsons) {
          _sendToWebSocket(jsonData);
          latestTelemetry = _parseTelemetryFromMap(jsonData);
        }
        
        return latestTelemetry;
      }
      
      return null;
    } catch (e) {
      print('❌ Error parsing string to telemetry: $e');
      return null;
    }
  }

  Telemetry? _parseTelemetryFromMap(Map<String, dynamic> payload) {
    try {
      final convertedPayload = _convertNumbers(payload);
      
      final deviceIdFromJson = convertedPayload['device_id'] as String? ?? 'HELMET_001';
      
      final enhancedPayload = Map<String, dynamic>.from(convertedPayload);
      enhancedPayload['device_id'] = deviceIdFromJson;
      
      final telemetry = Telemetry.fromJson(enhancedPayload);
      
      return telemetry;
    } catch (e) {
      print('❌ Error parsing map to telemetry: $e');
      return null;
    }
  }

  dynamic _convertNumbers(dynamic value) {
    if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((key, val) {
        result[key.toString()] = _convertNumbers(val);
      });
      return result;
    } else if (value is List) {
      return value.map(_convertNumbers).toList();
    } else if (value is String) {
      if (_isNumeric(value)) {
        if (value.contains('.') || value.contains('e') || value.contains('E')) {
          try {
            return double.parse(value);
          } catch (_) {
            return value;
          }
        } else {
          try {
            return int.parse(value);
          } catch (_) {
            return value;
          }
        }
      }
      return value;
    }
    return value;
  }

  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    final numericRegex = RegExp(r'^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$');
    return numericRegex.hasMatch(str);
  }

  void _handleStreamError(error) {
    if (error.toString().contains("disconnected") ||
        error.toString().contains("connection")) {
      emit(state.copyWith(
        connected: false,
        connectionStatus: "Disconnected",
        error: "Lost connection to device",
      ));
      
      _jsonBufferHelper.clear();
      _scheduleReconnect();
    }
  }

  void _handleStreamClosed() {
    if (state.connected) {
      emit(state.copyWith(
        connected: false,
        connectionStatus: "Connection closed",
        error: "Connection closed unexpectedly",
      ));
      _jsonBufferHelper.clear();
      _scheduleReconnect();
    }
  }

  Future<void> _connectWebSocketInBackground() async {
    unawaited(Future(() async {
      try {
        await ingest.connect();
        if (state.wsConnected == false) {
          emit(state.copyWith(wsConnected: true));
        }
      } catch (e) {
        print('⚠️ WebSocket connect failed: $e');
      }
    }));
  }

  Future<void> _sendToWebSocket(Map<String, dynamic> payload) async {
    try {
      final enhancedPayload = Map<String, dynamic>.from(payload);
      
      final jsonString = jsonEncode(enhancedPayload);
      
      print("📤 Sending telemetry to WebSocket: ${jsonString.length} bytes");

      await ingest.send(enhancedPayload);
      _packetsSent++;
      
      if (_packetsSent % 10 == 0) {
        emit(state.copyWith(packetsSent: _packetsSent));
      }
    } catch (e) {
      print('⚠️ WebSocket send failed: $e');
      if (state.wsConnected) {
        emit(state.copyWith(wsConnected: false));
        _connectWebSocketInBackground();
      }
    }
  }

  void _startHealthMonitoring() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(healthCheckInterval, (timer) {
      if (_lastDataTime != null && 
          DateTime.now().difference(_lastDataTime!) > dataTimeout &&
          state.connected) {
        
        if (state.connectionStatus != "Connected (Idle)") {
          emit(state.copyWith(
            connectionStatus: "Connected (Idle)",
          ));
        }
      }
    });
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_mac != null && !_starting && !state.connected) {
        print("🔄 Attempting auto-reconnect to $_mac...");
        startWithMac(_mac!);
      }
    });
  }

  Future<void> disconnect() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    
    await _sub?.cancel();
    _sub = null;
    
    _jsonBufferHelper.clear();
    
    try {
      await source.disconnect();
    } catch (_) {}
    
    emit(TelemetryState(
      loading: false,
      error: null,
      data: state.data,
      currentRisk: state.currentRisk,
      riskWsConnected: state.riskWsConnected,
      connected: false,
      connectionStatus: "Disconnected",
    ));
  }

  Future<void> reconnect() async {
    if (_mac != null) {
      await startWithMac(_mac!);
    }
  }

  void updateRiskData(RiskData riskData) {
    print('🔄 Manually updating risk data: ${riskData.level}');
    emit(state.copyWith(
      currentRisk: riskData,
    ));
  }

  @override
  Future<void> close() async {
    await _riskWebSocketSubscription?.cancel();
    _riskWebSocketSubscription = null;
    await _riskWebSocket?.sink.close();
    _riskWebSocket = null;
    
    _healthTimer?.cancel();
    await _sub?.cancel();
    _jsonBufferHelper.clear();
    await source.dispose();
    await ingest.close();
    return super.close();
  }
}