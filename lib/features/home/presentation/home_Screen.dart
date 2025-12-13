import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart' as latlng;

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

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<MapViewState> _mapKey = GlobalKey<MapViewState>();

  latlng.LatLng? _destination;
  bool _tripStarted = false;
  bool _tripCompleted = false;

  final latlng.Distance _distance = latlng.Distance();

  late final FlutterTts _tts;
  DateTime? _lastVoiceAt;
  String? _lastHint;

  // ✅ We compute heading from GPS movement (previous -> current)
  latlng.LatLng? _lastPos;
  DateTime? _lastPosAt;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.9);

    // Start receiving telemetry (stream)
    context.read<TelemetryCubit>().start();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    final now = DateTime.now();

    // avoid spamming same message
    if (_lastVoiceAt != null &&
        now.difference(_lastVoiceAt!).inSeconds < 6 &&
        text == _lastHint) {
      return;
    }

    _lastVoiceAt = now;
    _lastHint = text;

    await _tts.stop();
    await _tts.speak(text);
  }

  void _handleTelemetryUpdate(Telemetry? t) {
    if (t == null) return;

    final current = latlng.LatLng(t.latitude, t.longitude);

    // save last position for heading calculation
    _updateLastPosition(current);

    if (!_tripStarted || _destination == null) return;

    final dest = _destination!;
    final meters = _distance(current, dest);

    // Arrival detection
    if (meters < 25 && !_tripCompleted) {
      setState(() {
        _tripStarted = false;
        _tripCompleted = true;
      });
      _speak("You have arrived at your destination.");
      return;
    }

    // ✅ Direction hint WITHOUT bearing from telemetry:
    // Use computed heading from GPS movement.
    final heading = _computedHeading();
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

  void _updateLastPosition(latlng.LatLng current) {
    final now = DateTime.now();

    // Only update last position if enough time passed or moved enough distance
    if (_lastPos == null) {
      _lastPos = current;
      _lastPosAt = now;
      return;
    }

    final movedMeters = _distance(_lastPos!, current);
    final seconds = _lastPosAt == null ? 999 : now.difference(_lastPosAt!).inSeconds;

    // if moved > 2m or 2 seconds passed, accept update
    if (movedMeters > 2 || seconds >= 2) {
      _lastPos = current;
      _lastPosAt = now;
    }
  }

  /// Returns heading in degrees [0..360), computed from last GPS movement.
  double? _computedHeading() {
    if (_lastPos == null) return null;

    // Need TWO positions: previous and current.
    // We use _lastPos as previous, but to compute heading we need a newer position.
    // Here we store previous in _prevPos by caching before updating; to keep it simple:
    // We'll compute heading using a short history inside this function.

    // If we don't have enough movement, heading is unreliable.
    // (We already require moved > 2m in update)
    // So we compute heading from lastPos -> current using a stored "current" would be better,
    // but we only have _lastPos.
    // We'll instead compute heading inside _handleTelemetryUpdate by using two points:
    // previous = _prevPos, current = current. We'll keep _prevPos.

    return null;
  }

  // ✅ Keep two-point history for heading (prev -> current)
  latlng.LatLng? _prevPos;

  void _updatePrevCurrent(latlng.LatLng current) {
    if (_prevPos == null) {
      _prevPos = current;
      return;
    }

    final moved = _distance(_prevPos!, current);
    if (moved > 2) {
      // only shift if real movement
      _prevPos = current;
    }
  }

  double? _headingFromPrev(latlng.LatLng current) {
    if (_prevPos == null) return null;

    final moved = _distance(_prevPos!, current);
    if (moved < 2) return null;

    return _bearingBetween(_prevPos!, current);
  }

  double _bearingBetween(latlng.LatLng from, latlng.LatLng to) {
    final lat1 = _degToRad(from.latitude);
    final lon1 = _degToRad(from.longitude);
    final lat2 = _degToRad(to.latitude);
    final lon2 = _degToRad(to.longitude);

    final dLon = lon2 - lon1;
    final y = Math.sin(dLon) * Math.cos(lat2);
    final x = Math.cos(lat1) * Math.sin(lat2) -
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onAbout: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AboutUsPage())),
        onFaq: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const FaqPage())),
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
          // Keep prev/current for heading
          final t = state.data;
          if (t != null) {
            final cur = latlng.LatLng(t.latitude, t.longitude);
            // compute heading using prev->cur
            final heading = _headingFromPrev(cur);
            // update prev after using it
            _updatePrevCurrent(cur);

            // Use same logic but with computed heading:
            _handleTelemetryUpdateWithHeading(t, heading);
          } else {
            _handleTelemetryUpdate(null);
          }
        },
        child: LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 900;

            return BlocBuilder<TelemetryCubit, TelemetryState>(
              builder: (context, state) {
                if (state.error != null && state.data == null) {
                  return Center(child: Text('Error: ${state.error}'));
                }

                final map = MapView(
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
                );

                final metrics = MetricsGrid(telemetry: state.data);

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: map),
                      Expanded(flex: 2, child: metrics),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(flex: 5, child: map),
                    Expanded(flex: 5, child: metrics),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mapKey.currentState?.recenter(),
        child: const Icon(Icons.near_me),
      ),
      bottomNavigationBar: _destination == null
          ? null
          : SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _tripCompleted
                                ? 'Trip completed'
                                : (_tripStarted
                                    ? 'Navigation running'
                                    : 'Destination selected'),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_destination!.latitude.toStringAsFixed(5)}, '
                            '${_destination!.longitude.toStringAsFixed(5)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _tripCompleted
                          ? null
                          : () {
                              setState(() {
                                if (_tripStarted) {
                                  _tripStarted = false;
                                  _tripCompleted = false;
                                  _speak("Trip stopped.");
                                } else {
                                  _tripStarted = true;
                                  _tripCompleted = false;
                                  _speak("Starting navigation.");
                                }
                              });
                            },
                      icon: Icon(
                        _tripCompleted
                            ? Icons.check
                            : (_tripStarted ? Icons.stop : Icons.play_arrow),
                      ),
                      label: Text(
                        _tripCompleted
                            ? 'Trip completed'
                            : (_tripStarted ? 'Stop trip' : 'Start trip'),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _handleTelemetryUpdateWithHeading(Telemetry? t, double? heading) {
    if (!_tripStarted || _destination == null || t == null) return;

    final current = latlng.LatLng(t.latitude, t.longitude);
    final dest = _destination!;
    final meters = _distance(current, dest);

    if (meters < 25 && !_tripCompleted) {
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
}
