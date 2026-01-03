import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  late final FlutterTts _tts;
  DateTime? _lastVoiceAt;
  String? _lastHint;

  latlng.LatLng? _prevPos;

  String? _selectedMac;
  bool _connecting = false;
  bool _autoReconnectAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _tts = FlutterTts();
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.9);

    _loadSavedMacAndAutoConnect();
  }

  Future<void> _loadSavedMacAndAutoConnect() async {
    final mac = await EspPrefs.loadMac();
    if (!mounted) return;
    
    setState(() => _selectedMac = mac);
    
    if (mac != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(seconds: 2)); // Wait for app to settle
        if (mounted && !_autoReconnectAttempted) {
          await _silentAutoReconnect(mac);
        }
      });
    }
  }

  Future<void> _silentAutoReconnect(String mac) async {
    if (_connecting || _autoReconnectAttempted) return;
    
    _autoReconnectAttempted = true;
    
    // Wait a bit before auto-reconnecting
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
      // Don't show error - it's automatic
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
    super.dispose();
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

  Future<void> _checkPermissionsAndConnect() async {
    // Check and request permissions
    final locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted) {
      _showSnackBar("Location permission is required for Bluetooth");
      return;
    }

    // Open device selection
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

      // Check if device is paired (simplified check)
      final bool isLikelyPaired = await _checkIfDeviceIsPaired(mac);
      if (!isLikelyPaired) {
        // Show pairing instructions
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
    // Simplified check - in production, use platform-specific code
    // For now, we'll show pairing instructions for any new device
    final savedMac = await EspPrefs.loadMac();
    return savedMac == mac; // If we've connected before, assume it's paired
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
              openAppSettings(); // Open system settings
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
      return "Device not responding. Please:\n1. Check if powered on\n2. Ensure it's paired\n3. Stay within range";
    }
    
    if (errorStr.contains("timeout")) {
      return "Connection timeout. Device may be out of range.";
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
      _showSnackBar("Connection timeout - check device power and range");
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
    
    if (!shouldShowCard) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Container(
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
            // Loading indicator or icon
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  // Status message with loading dots
                  if (state.loading)
                    Row(
                      children: [
                        Text(
                          state.connectionStatus ?? "Connecting",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildLoadingDots(),
                      ],
                    ),
                  
                  // Error message
                  if (state.error != null)
                    Text(
                      state.error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  // Disconnected state
                  if (!state.connected && !state.loading && state.error == null)
                    Text(
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
            
            // Connect/Reconnect buttons
            if (_selectedMac == null)
              ElevatedButton(
                onPressed: _connecting ? null : _checkPermissionsAndConnect,
                child: _connecting 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
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
    );
  }

  // Loading dots animation
  Widget _buildLoadingDots() {
    return SizedBox(
      width: 20,
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAnimatedDot(0),
          const SizedBox(width: 2),
          _buildAnimatedDot(1),
          const SizedBox(width: 2),
          _buildAnimatedDot(2),
        ],
      ),
    );
  }

  Widget _buildAnimatedDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        final offset = (value * 3 + index) % 3;
        final opacity = offset < 1 ? offset : (2 - offset);
        
        return Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(opacity.clamp(0.3, 1.0)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildErrorState(TelemetryState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            state.error ?? "Connection error",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[800]),
          ),
          const SizedBox(height: 16),
          if (_selectedMac != null)
            ElevatedButton(
              onPressed: _reconnectSaved,
              child: const Text("Try Again"),
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
            const SizedBox(height: 8),
            Text(
              'Please wait',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
            const SizedBox(height: 16),
            if (_selectedMac != null)
              ElevatedButton.icon(
                onPressed: _reconnectSaved,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Connection'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryContent(BuildContext context, TelemetryState state) {
    if (state.loading) return _buildLoadingState();
    if (state.error != null && state.data == null) return _buildErrorState(state);
    if (state.data == null) return _buildWaitingForData();

    return MetricsGrid(telemetry: state.data!);
  }

  // Navigation functions
  void _handleTelemetryUpdateWithHeading(Telemetry? t, double? heading) {
    if (!_tripStarted || _destination == null || t == null) return;

    final current = latlng.LatLng(t.lat, t.lon);
    final dest = _destination!;
    final meters = _distance(current, dest);

    if (meters < 25 && !_tripCompleted) {
      if (!mounted) return;
      setState(() {
        _tripStarted = false;
        _tripCompleted = true;
      });
      _speak("You have arrived at your destination.");
      return;
    }

    if (heading == null) {
      _speak("Head towards your destination.");
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

    _speak(hint);
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
        },
        child: BlocBuilder<TelemetryCubit, TelemetryState>(
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Connection Card
                  _buildConnectionCard(state),

                  // Map View
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
                        });
                      },
                    ),
                  ),

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