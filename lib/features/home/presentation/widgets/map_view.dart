import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:http/http.dart' as http;

class MapView extends StatefulWidget {
  final Telemetry? telemetry;
  final latlng.LatLng? destination;
  final bool tripActive;
  final ValueChanged<latlng.LatLng>? onDestinationSelected;

  const MapView({
    super.key,
    required this.telemetry,
    this.destination,
    required this.tripActive,
    this.onDestinationSelected,
  });

  @override
  MapViewState createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  bool _centeredOnce = false;

  static final latlng.LatLng _fallbackCenter = latlng.LatLng(
    33.8938,
    35.5018,
  ); // Beirut

  // 🟦 Road route points returned from OSRM
  List<latlng.LatLng> _routePoints = [];
  bool _fetchingRoute = false;
  latlng.LatLng? _lastFrom;
  latlng.LatLng? _lastTo;

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeRequestRoute();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.telemetry;
    final latlng.LatLng? me = (t == null)
        ? null
        : latlng.LatLng(t.latitude, t.longitude);

    // 🔵 driver + 🔴 destination markers
    final markers = <Marker>[
      if (me != null)
        Marker(
          point: me,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00D1FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.pedal_bike, color: Colors.white, size: 22),
          ),
        ),
      if (widget.destination != null)
        Marker(
          point: widget.destination!,
          width: 38,
          height: 38,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 20),
          ),
        ),
    ];

    // 🟦 polyline now uses OSRM route (road path), not straight line
    final polylines = <Polyline>[
      if (_routePoints.isNotEmpty && widget.tripActive)
        Polyline(
          points: _routePoints,
          strokeWidth: 4,
          color: Colors.blueAccent,
        ),
    ];

    _maybeCenter(me);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _fallbackCenter,
              initialZoom: 14.5,
              minZoom: 3,
              maxZoom: 19,
              keepAlive: true,
              onTap: (tapPos, point) {
                if (widget.onDestinationSelected != null) {
                  // user chooses a new destination
                  widget.onDestinationSelected!(point);
                  // clear old route so we fetch a new one
                  setState(() {
                    _routePoints = [];
                    _lastFrom = null;
                    _lastTo = null;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.isd',
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),
        ),

        // Small hint when there is no destination yet
        if (widget.destination == null)
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, size: 16, color: Colors.white70),
                  SizedBox(width: 6),
                  Text(
                    'Tap on map to select destination',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 🔁 Ask routing server for a road path when we have both current location & destination
  void _maybeRequestRoute() {
    final t = widget.telemetry;
    if (t == null || widget.destination == null) return;

    final from = latlng.LatLng(t.latitude, t.longitude);
    final to = widget.destination!;

    // if from/to didn't really change, don't refetch
    if (_lastFrom != null &&
        _lastTo != null &&
        _lastFrom!.latitude == from.latitude &&
        _lastFrom!.longitude == from.longitude &&
        _lastTo!.latitude == to.latitude &&
        _lastTo!.longitude == to.longitude) {
      return;
    }

    _fetchRoute(from, to);
  }

  Future<void> _fetchRoute(latlng.LatLng from, latlng.LatLng to) async {
    if (_fetchingRoute) return;
    _fetchingRoute = true;

    try {
      // Using OSRM (Open Source Routing Machine) public demo server
      // NOTE: good for dev/testing, for production you should host your own or use a provider.
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List<dynamic>;

          final points = coords
              .map(
                (c) => latlng.LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ),
              )
              .toList();

          if (mounted) {
            setState(() {
              _routePoints = points;
              _lastFrom = from;
              _lastTo = to;
            });
          }
        }
      } else {
        // you can log or handle errors here if you want
      }
    } catch (e) {
      // handle network errors if needed
    } finally {
      _fetchingRoute = false;
    }
  }

  void _maybeCenter(latlng.LatLng? me) {
    if (me == null || _centeredOnce) return;
    _centeredOnce = true;
    _mapController.move(me, 16);
  }

  void recenter() {
    final t = widget.telemetry;
    if (t == null) return;
    final me = latlng.LatLng(t.latitude, t.longitude);
    _mapController.move(me, 17);
  }
}
