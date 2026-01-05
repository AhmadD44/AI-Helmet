import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:isd/features/home/presentation/widgets/risk_indicator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:permission_handler/permission_handler.dart';

import 'package:isd/core/utils/esp_prefs.dart';
import 'package:isd/features/home/presentation/connect_esp_page.dart';
import 'package:isd/features/home/presentation/allTrips/my_trips.dart';

import 'package:isd/features/home/presentation/widgets/about_us.dart';
import 'package:isd/features/home/presentation/widgets/drawer.dart';
import 'package:isd/features/home/presentation/widgets/faq.dart';
import 'package:isd/features/home/presentation/widgets/map_view.dart';
import 'package:isd/features/home/presentation/widgets/metrics_grid.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'package:isd/features/home/presentation/widgets/telemetry_cubit.dart';
import 'package:isd/features/home/presentation/widgets/crash_alert_page.dart';

class HomeScreen extends StatefulWidget {
  final Future<void> Function()? onSignOut;
  const HomeScreen({super.key, this.onSignOut});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final GlobalKey<MapViewState> _mapKey = GlobalKey<MapViewState>();

  latlng.LatLng? _destination;
  bool _tripStarted = false;
  bool _tripCompleted = false;
  final latlng.Distance _distance = latlng.Distance();
  
  // Routing
  List<latlng.LatLng> _routePoints = [];

  late final FlutterTts _tts;
  DateTime? _lastVoiceAt;
  String? _lastHint;

  latlng.LatLng? _prevPos;

  String? _selectedMac;
  bool _connecting = false;
  bool _autoReconnectAttempted = false;

  RiskData? _currentRisk;
  bool _showingCrashAlert = false;
  Timer? _crashCountdownTimer;
  int _crashCountdownSeconds = 10;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _tts = FlutterTts();
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.9);

    _loadSavedMacAndAutoConnect();
  }

  Widget _buildStartTripButton() {
    if (_destination == null || _tripStarted) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.navigation),
        label: const Text(
          "Start Trip",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: () {
          setState(() {
            _tripStarted = true;
            _tripCompleted = false;
          });

          // Speak route info
          if (_routePoints.isNotEmpty) {
            final routeDistance = _calculateRouteDistance(_routePoints);
            _tts.speak("Trip started. Follow the ${routeDistance.toStringAsFixed(1)} kilometer route.");
          } else {
            _tts.speak("Trip started. Follow the route.");
          }
        },
      ),
    );
  }

  // Calculate total route distance
  double _calculateRouteDistance(List<latlng.LatLng> points) {
    double total = 0.0;
    
    for (int i = 0; i < points.length - 1; i++) {
      total += _distance(points[i], points[i + 1]);
    }
    
    return total / 1000; // Return in kilometers
  }

  // Find nearest point on route for turn guidance
  int _findNearestRoutePoint(latlng.LatLng current) {
    int nearestIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < _routePoints.length; i++) {
      final dist = _distance(current, _routePoints[i]);
      if (dist < minDistance) {
        minDistance = dist;
        nearestIndex = i;
      }
    }
    
    return nearestIndex;
  }

  Future<void> _loadSavedMacAndAutoConnect() async {
    final mac = await EspPrefs.loadMac();
    if (!mounted) return;
    
    setState(() => _selectedMac = mac);
    
    if (mac != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && !_autoReconnectAttempted) {
          await _silentAutoReconnect(mac);
        }
      });
    }
  }

  Future<void> _silentAutoReconnect(String mac) async {
    if (_connecting || _autoReconnectAttempted) return;
    
    _autoReconnectAttempted = true;
    
    await Future.delayed(const Duration(seconds: 1));
    
    print("🔄 Auto-reconnecting to $mac...");
    
    try {
      await context.read<TelemetryCubit>()
          .startWithMac(mac)
          .timeout(const Duration(seconds: 10));
          
      print("✅ Auto-reconnect successful");
    } on TimeoutException {
      print("⏰ Auto-reconnect timeout");
    } catch (e) {
      print("⚠️ Auto-reconnect failed: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && 
        _selectedMac != null && 
        !_autoReconnectAttempted) {
      
      final cubit = context.read<TelemetryCubit>();
      if (!cubit.state.connected) {
        _silentAutoReconnect(_selectedMac!);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
    _crashCountdownTimer?.cancel();
    super.dispose();
  }

  void _handleRiskUpdate(RiskData riskData) {
    setState(() {
      _currentRisk = riskData;
    });
    
    if (riskData.isCrash && !_showingCrashAlert) {
      print('🚨 CRASH DETECTED! Showing alert...');
      _showCrashAlert(riskData);
    }
  }

  void _showCrashAlert(RiskData risk) {
    if (_showingCrashAlert) return;
    
    _showingCrashAlert = true;
    _crashCountdownSeconds = 10;
    
    _tts.speak("CRASH DETECTED! Emergency alert activated.");
    
    _startCrashCountdown();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => CrashAlertPage(
        riskData: risk,
        onCancel: () {
          _cancelCrashAlert();
        },
        onConfirm: () {
          _confirmCrashEmergency(risk);
        },
      ),
    ).then((_) {
      _showingCrashAlert = false;
      _crashCountdownTimer?.cancel();
    });
  }

  void _startCrashCountdown() {
    _crashCountdownTimer?.cancel();
    _crashCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_crashCountdownSeconds > 0) {
        setState(() {
          _crashCountdownSeconds--;
        });
        
        if (_crashCountdownSeconds == 5) {
          _tts.speak("5 seconds until emergency call");
        }
        
        if (_crashCountdownSeconds <= 0) {
          _triggerEmergencyServices();
          timer.cancel();
        }
      }
    });
  }

  void _cancelCrashAlert() {
    _crashCountdownTimer?.cancel();
    _showingCrashAlert = false;
    
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('⚠️ Crash alert cancelled by user');
    _tts.speak("Crash alert cancelled");
  }

  void _confirmCrashEmergency(RiskData risk) {
    _crashCountdownTimer?.cancel();
    _showingCrashAlert = false;
    
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('🚨 Emergency confirmed! Calling services...');
    _tts.speak("Emergency services notified");
  }

  void _triggerEmergencyServices() {
    if (_showingCrashAlert) {
      print('⏰ Countdown finished! Triggering emergency services...');
      _tts.speak("Automatic emergency call activated");
    }
  }

  Future<void> _speak(String text) async {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastVoiceAt != null &&
        now.difference(_lastVoiceAt!).inSeconds < 6 &&
        text == _lastHint) {
      return;
    }
    _lastVoiceAt = now;
    _lastHint = text;

    await _tts.stop();
    if (!mounted) return;
    await _tts.speak(text);
  }

  // Enhanced voice guidance using route points
  Future<void> _handleTelemetryUpdateWithHeading(Telemetry? t, double? heading) async {
    if (!_tripStarted || _destination == null || t == null) return;

    final current = latlng.LatLng(t.lat, t.lon);
    final dest = _destination!;
    
    // Check arrival using direct distance
    final metersToDest = _distance(current, dest);
    if (metersToDest < 25 && !_tripCompleted) {
      if (!mounted) return;
      setState(() {
        _tripStarted = false;
        _tripCompleted = true;
      });
      await _speak("You have arrived at your destination.");
      return;
    }

    // Enhanced turn guidance using route points
    if (_routePoints.isNotEmpty && heading != null) {
      final nearestIndex = _findNearestRoutePoint(current);
      
      if (nearestIndex < _routePoints.length - 1) {
        final nextPoint = _routePoints[nearestIndex + 1];
        final metersToNext = _distance(current, nextPoint);
        
        // Check if approaching a turn (within 100m)
        if (metersToNext < 100) {
          final bearingToNext = _bearingBetween(current, nextPoint);
          final delta = _normalizeAngle(bearingToNext - heading);
          
          String hint;
          if (delta > 30) {
            hint = "Prepare to turn right in ${metersToNext.toStringAsFixed(0)} meters.";
          } else if (delta < -30) {
            hint = "Prepare to turn left in ${metersToNext.toStringAsFixed(0)} meters.";
          } else if (delta.abs() > 10) {
            hint = "Slight adjustment needed.";
          } else {
            hint = "Continue straight.";
          }
          
          await _speak(hint);
          return;
        }
      }
    }

    // Fallback to original guidance
    if (heading == null) {
      await _speak("Head towards your destination.");
      return;
    }

    final bearingToDest = _bearingBetween(current, dest);
    final delta = _normalizeAngle(bearingToDest - heading);

    String hint;
    if (delta > 25) {
      hint = "Turn right towards your destination.";
    } else if (delta < -25) {
      hint = "Turn left towards your destination.";
    } else {
      hint = "Continue straight.";
    }

    await _speak(hint);
  }

  double? _headingFromPrev(latlng.LatLng current) {
    if (_prevPos == null) {
      _prevPos = current;
      return null;
    }
    final moved = _distance(_prevPos!, current);
    if (moved < 2) return null;
    final h = _bearingBetween(_prevPos!, current);
    _prevPos = current;
    return h;
  }

  double _bearingBetween(latlng.LatLng from, latlng.LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lon1 = _degToRad(from.longitude);
    final lat2 = _degToRad(to.latitude);
    final lon2 = _degToRad(to.longitude);

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final brng = math.atan2(y, x);
    return (_radToDeg(brng) + 360) % 360;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
  double _radToDeg(double rad) => rad * (180.0 / math.pi);

  double _normalizeAngle(double angle) {
    double a = angle % 360;
    if (a > 180) a -= 360;
    if (a < -180) a += 360;
    return a;
  }

  Future<void> _checkPermissionsAndConnect() async {
    final locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted) {
      _showSnackBar("Location permission is required for Bluetooth");
      return;
    }

    await _pickAndConnectEsp();
  }

  Future<void> _pickAndConnectEsp() async {
    if (_connecting) return;
    setState(() => _connecting = true);

    try {
      final mac = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ConnectEspPage(
            source: context.read<TelemetryCubit>().source,
          ),
        ),
      );

      if (mac == null) {
        setState(() => _connecting = false);
        return;
      }

      final bool isLikelyPaired = await _checkIfDeviceIsPaired(mac);
      if (!isLikelyPaired) {
        await _showPairingInstructions(mac);
        setState(() => _connecting = false);
        return;
      }

      await _saveAndConnect(mac);
    } catch (e) {
      _showSnackBar("Connection failed: ${_parseErrorForUser(e)}");
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _saveAndConnect(String mac) async {
    await EspPrefs.saveMac(mac);
    if (!mounted) return;
    
    setState(() => _selectedMac = mac);
    await context.read<TelemetryCubit>().startWithMac(mac);
  }

  Future<bool> _checkIfDeviceIsPaired(String mac) async {
    final savedMac = await EspPrefs.loadMac();
    return savedMac == mac;
  }

  Future<void> _showPairingInstructions(String mac) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth, color: Colors.blue),
            SizedBox(width: 10),
            Text("Pairing Required"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("To connect to your helmet, please:"),
              const SizedBox(height: 16),
              _buildInstructionStep(1, "Open Android Settings"),
              _buildInstructionStep(2, "Go to 'Connected Devices'"),
              _buildInstructionStep(3, "Select 'Pair new device'"),
              _buildInstructionStep(4, "Look for 'HELMET_001' and pair"),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Device Information:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text("Name: HELMET_001"),
                    Text("MAC: $mac"),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveAndConnect(mac);
            },
            child: const Text("I've Paired It"),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  String _parseErrorForUser(dynamic e) {
    final errorStr = e.toString();
    
    if (errorStr.contains("connection_failed") || errorStr.contains("could not connect")) {
      return "Device not responding.";
    }
    
    if (errorStr.contains("timeout")) {
      return "Connection timeout.";
    }
    
    if (errorStr.contains("permission")) {
      return "Bluetooth permission needed.";
    }
    
    return "Please try again";
  }

  Future<void> _reconnectSaved() async {
    final mac = _selectedMac;
    if (mac == null) return;

    if (_connecting) return;
    setState(() => _connecting = true);

    try {
      await context
          .read<TelemetryCubit>()
          .startWithMac(mac)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      _showSnackBar("Connection timeout");
    } catch (e) {
      _showSnackBar("Reconnect failed: ${_parseErrorForUser(e)}");
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _forgetDevice() async {
    await EspPrefs.clearMac();
    await context.read<TelemetryCubit>().disconnect();
    if (!mounted) return;
    setState(() {
      _selectedMac = null;
      _autoReconnectAttempted = false;
    });
    _showSnackBar("Device forgotten");
  }

  Widget _buildConnectionCard(TelemetryState state) {
    final shouldShowCard = state.loading || 
        state.error != null || 
        !state.connected || 
        _selectedMac == null;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        children: [
          // Bluetooth Connection Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: state.error != null ? Colors.red.withOpacity(0.5) : 
                       state.loading ? Colors.blue.withOpacity(0.5) :
                       Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (state.loading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.blue[400]!),
                    ),
                  )
                else
                  Icon(
                    Icons.bluetooth,
                    size: 22,
                    color: state.error != null ? Colors.red :
                           !state.connected ? Colors.orange :
                           Colors.green,
                  ),
                
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMac == null
                            ? "No helmet connected"
                            : "Helmet: ${_selectedMac?.substring(_selectedMac!.length - 8)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      if (state.loading)
                        Text(
                          state.connectionStatus ?? "Connecting",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      
                      if (state.error != null)
                        Text(
                          state.error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      
                      if (!state.connected && !state.loading && state.error == null)
                        const Text(
                          "Disconnected",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                
                if (_selectedMac == null)
                  ElevatedButton(
                    onPressed: _connecting ? null : _checkPermissionsAndConnect,
                    child: _connecting 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text("Connect"),
                  )
                else ...[
                  OutlinedButton(
                    onPressed: _connecting ? null : _reconnectSaved,
                    child: _connecting 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.blue),
                            ),
                          )
                        : const Text("Reconnect"),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: "Forget device",
                    onPressed: _connecting ? null : _forgetDevice,
                    icon: _connecting 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.grey),
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Risk WebSocket Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.riskWsConnected ? Colors.green : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud,
                  size: 20,
                  color: state.riskWsConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.riskWsConnected 
                        ? "Risk monitoring: Connected"
                        : "Risk monitoring: Connecting...",
                    style: TextStyle(
                      color: state.riskWsConnected ? Colors.green : Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              "Connecting to helmet...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForData() {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_connected,
              size: 48,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Connected to Helmet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Waiting for telemetry data...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryContent(BuildContext context, TelemetryState state) {
    if (state.loading) return _buildLoadingState();
    if (state.error != null && state.data == null) return Container();
    if (state.data == null) return _buildWaitingForData();

    return MetricsGrid(telemetry: state.data!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onMyTrips: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MyTripsPage()),
        ),
        onAbout: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AboutUsPage()),
        ),
        onFaq: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FaqPage()),
        ),
        onSignOut: widget.onSignOut,
      ),
      appBar: AppBar(
        title: Text(
          _tripCompleted
              ? 'Trip completed'
              : (_tripStarted ? 'Trip in progress' : 'Driver Dashboard'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.warning, color: Colors.orange),
            onPressed: () {
              final testRisk = RiskData(
                level: 'HIGH',
                score: 95,
                reasons: ['Test crash'],
                speedKmh: 60.0,
              );
              
              context.read<TelemetryCubit>().updateRiskData(testRisk);
            },
            tooltip: 'Test risk data',
          ),
          IconButton(
            tooltip: 'Recenter',
            onPressed: () => _mapKey.currentState?.recenter(),
            icon: const Icon(Icons.my_location),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocListener<TelemetryCubit, TelemetryState>(
        listener: (context, state) {
          final t = state.data;
          if (t != null) {
            final cur = latlng.LatLng(t.lat, t.lon);
            final heading = _headingFromPrev(cur);
            _handleTelemetryUpdateWithHeading(t, heading);
          }
          
          if (state.currentRisk != null && state.currentRisk != _currentRisk) {
            _handleRiskUpdate(state.currentRisk!);
          }
        },
        child: BlocBuilder<TelemetryCubit, TelemetryState>(
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Connection Cards
                  _buildConnectionCard(state),

                  // Risk Status Indicator
                  if (state.currentRisk != null)
                    RiskStatusIndicator(
                      riskData: state.currentRisk,
                      onTap: () {
                        if (state.currentRisk != null && state.currentRisk!.isCrash) {
                          _showCrashAlert(state.currentRisk!);
                        }
                      },
                    ),

                  // Map View with Routing
                  SizedBox(
                    height: 400,
                    child: MapView(
                      key: _mapKey,
                      telemetry: state.data,
                      destination: _destination,
                      tripActive: _tripStarted,
                      onDestinationSelected: (dest) {
                        setState(() {
                          _destination = dest;
                          _tripStarted = false;
                          _tripCompleted = false;
                          _routePoints.clear();
                        });
                      },
                      onTripStatusChanged: (isActive) {
                        setState(() {
                          _tripStarted = isActive;
                        });
                      },
                      onTripStarted: (destination) {
                        // Could add trip start logic here
                      },
                      onRouteCalculated: (routePoints) {
                        setState(() {
                          _routePoints = routePoints;
                        });
                      },
                    ),
                  ),
                  
                  // Start Trip Button
                  _buildStartTripButton(),

                  // Telemetry Content
                  _buildTelemetryContent(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}