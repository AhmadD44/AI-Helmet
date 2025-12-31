import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart' as latlng;

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

    // ✅ Load saved MAC
    _loadSavedMacAndAutoConnect();
  }

  Future<void> _loadSavedMacAndAutoConnect() async {
    final mac = await EspPrefs.loadMac();
    if (!mounted) return;
    
    setState(() => _selectedMac = mac);
    
    // ✅ Auto-reconnect if we have a saved MAC
    if (mac != null) {
      // Wait for UI to build and cubit to be available
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && !_autoReconnectAttempted) {
          await _silentAutoReconnect(mac);
        }
      });
    }
  }

  Future<void> _silentAutoReconnect(String mac) async {
    if (_connecting || _autoReconnectAttempted) return;
    
    _autoReconnectAttempted = true;
    print("🔄 Auto-reconnecting to $mac...");
    
    try {
      await context.read<TelemetryCubit>()
          .startWithMac(mac)
          .timeout(const Duration(seconds: 12));
          
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
    // Auto-reconnect when app returns to foreground
    if (state == AppLifecycleState.resumed && 
        _selectedMac != null && 
        !_autoReconnectAttempted) {
      
      // Check if we need to reconnect
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

  // ====== CONNECT FLOW (manual) ======
  Future<void> _pickAndConnectEsp() async {
    if (_connecting) return;
    setState(() => _connecting = true);

    try {
      // Open scanner page
      final mac = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ConnectEspPage(source: context.read<TelemetryCubit>().source),
        ),
      );

      if (mac == null) {
        if (!mounted) return;
        setState(() => _connecting = false);
        return; // user canceled
      }

      await EspPrefs.saveMac(mac);
      if (!mounted) return;
      setState(() => _selectedMac = mac);

      // Start BT stream now
      await context.read<TelemetryCubit>().startWithMac(mac);
    } catch (e) {
      // never crash
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Connect failed: $e")));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
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
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Connection timeout")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Reconnect failed: $e")));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _forgetDevice() async {
    await EspPrefs.clearMac();
    await context.read<TelemetryCubit>().disconnect();
    if (!mounted) return;
    setState(() {
      _selectedMac = null;
      _autoReconnectAttempted = false;
    });
  }

  // ===== navigation hints (optional) =====
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
    final y = Math.sin(dLon) * Math.cos(lat2);
    final x =
        Math.cos(lat1) * Math.sin(lat2) -
        Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

    final brng = Math.atan2(y, x);
    return (_radToDeg(brng) + 360) % 360;
  }

  double _degToRad(double deg) => deg * (Math.pi / 180.0);
  double _radToDeg(double rad) => rad * (180.0 / Math.pi);

  double _normalizeAngle(double angle) {
    double a = angle % 360;
    if (a > 180) a -= 360;
    if (a < -180) a += 360;
    return a;
  }
  // ===== end nav hints =====

  // ===== UI Helper Methods =====
  
  Widget _buildConnectionCard(TelemetryState state) {
    // Show card when: loading, has error, disconnected, or no saved MAC
    final shouldShowCard = state.loading || 
        state.error != null || 
        !state.connected || 
        _selectedMac == null;
    
    // Hide card when everything is good
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
            Icon(
              Icons.bluetooth,
              size: 22,
              color: state.loading ? Colors.blue :
                     state.error != null ? Colors.red :
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
                        ? "No ESP connected"
                        : "Saved ESP: $_selectedMac",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (state.loading)
                    Text(
                      "Connecting...",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                  if (state.error != null)
                    Text(
                      "Error: ${state.error}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!state.connected && !state.loading && state.error == null)
                    Text(
                      "Disconnected",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  // Auto-reconnect status
                  if (_autoReconnectAttempted && !state.connected && !state.loading)
                    Text(
                      "Auto-reconnect attempted",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (_selectedMac == null)
              ElevatedButton(
                onPressed: _connecting ? null : _pickAndConnectEsp,
                child: Text(_connecting ? "..." : "Connect"),
              )
            else ...[
              OutlinedButton(
                onPressed: _connecting ? null : _reconnectSaved,
                child: Text(_connecting ? "..." : "Reconnect"),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Forget device",
                onPressed: _connecting ? null : _forgetDevice,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(TelemetryState state) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                "Telemetry error:\n${state.error}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _selectedMac != null ? _reconnectSaved : null,
                child: Text("Retry Connection"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingForTelemetry(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _selectedMac == null
                    ? "Connect your ESP to start receiving telemetry."
                    : "Connected to $_selectedMac\nWaiting for telemetry...",
                textAlign: TextAlign.center,
              ),
              if (_selectedMac != null)
                ElevatedButton(
                  onPressed: _reconnectSaved,
                  child: Text("Reconnect"),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryContent(BuildContext context, TelemetryState state) {
    // ✅ Loading state
    if (state.loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ Error state (no crash)
    if (state.error != null && state.data == null) {
      return _buildErrorState(state);
    }

    // ✅ Connected but waiting for telemetry packets
    if (state.data == null) {
      return _buildWaitingForTelemetry(context);
    }

    // ✅ Metrics Grid (with telemetry data)
    return MetricsGrid(telemetry: state.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onMyTrips: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyTripsPage())),
        onAbout: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AboutUsPage())),
        onFaq: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FaqPage())),
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
          // ✅ SINGLE BlocBuilder for entire UI
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  // ✅ Connection Card
                  _buildConnectionCard(state),

                  // ✅ Map View
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

                  // ✅ Telemetry Content (all states handled here)
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