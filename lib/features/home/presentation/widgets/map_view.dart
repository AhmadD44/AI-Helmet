import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import 'telemetry.dart';

class MapView extends StatefulWidget {
  final Telemetry? telemetry;
  final latlng.LatLng? destination;
  final bool tripActive;
  final void Function(latlng.LatLng dest)? onDestinationSelected;

  const MapView({
    super.key,
    required this.telemetry,
    this.destination,
    this.tripActive = false,
    this.onDestinationSelected,
  });

  @override
  State<MapView> createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  bool _centeredOnce = false;

  /// Check if GPS coordinates are valid (not 0,0 or unrealistic)
  bool get _hasValidGPS {
    final t = widget.telemetry;
    if (t == null) return false;
    
    // Check for Null Island (0,0)
    final isZeroZero = t.lat == 0.0 && t.lon == 0.0;
    
    // Check if coordinates are within reasonable bounds
    final isWithinBounds = t.lat >= -90 && t.lat <= 90 && 
                           t.lon >= -180 && t.lon <= 180;
    
    // Saida city bounds (approximate) - don't show if already in Saida area
    final inSaidaArea = t.lat > 33.5 && t.lat < 33.6 && 
                        t.lon > 35.3 && t.lon < 35.4;
    
    return !isZeroZero && isWithinBounds && !inSaidaArea;
  }

  /// Get Saida (Sidon), Lebanon coordinates
  latlng.LatLng get _saidaLocation {
    // Saida (Sidon), Lebanon coordinates
    // Latitude: 33.5631° N, Longitude: 35.3689° E
    return const latlng.LatLng(33.5631, 35.3689);
  }

  /// Public method (used by HomeScreen)
  void recenter() {
    if (_hasValidGPS && widget.telemetry != null) {
      _mapController.move(
        latlng.LatLng(widget.telemetry!.lat, widget.telemetry!.lon),
        16,
      );
    } else {
      // Center to Saida, Lebanon
      _mapController.move(_saidaLocation, 13);
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize map to Saida immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(_saidaLocation, 13);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Center only ONCE after first valid telemetry
    if (!_centeredOnce && _hasValidGPS && widget.telemetry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _mapController.move(
          latlng.LatLng(widget.telemetry!.lat, widget.telemetry!.lon),
          16,
        );
        _centeredOnce = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which location to show
    final currentLocation = _hasValidGPS && widget.telemetry != null
        ? latlng.LatLng(widget.telemetry!.lat, widget.telemetry!.lon)
        : _saidaLocation;

    // Determine initial zoom level
    final initialZoom = _hasValidGPS ? 16.0 : 13.0;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentLocation,
            initialZoom: initialZoom,
            onTap: (tapPosition, point) {
              if (widget.onDestinationSelected != null) {
                widget.onDestinationSelected!(point);
              }
            },
          ),
          children: [
            // 🌍 Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.isd',
              tileProvider: NetworkTileProvider(),
            ),

            // 📍 Current position (only if valid GPS)
            if (_hasValidGPS && widget.telemetry != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 42,
                    height: 42,
                    point: currentLocation,
                    child: const Icon(
                      Icons.navigation,
                      size: 36,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),

            // 📍 Saida marker (when GPS is invalid)
            if (!_hasValidGPS)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: _saidaLocation,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_city,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

            // 🎯 Destination marker
            if (widget.destination != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: widget.destination!,
                    child: const Icon(
                      Icons.flag,
                      size: 34,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

            // ➖ Route line (only if valid GPS and trip active)
            if (widget.tripActive &&
                widget.destination != null &&
                _hasValidGPS &&
                widget.telemetry != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [currentLocation, widget.destination!],
                    strokeWidth: 4,
                    color: Colors.greenAccent,
                  ),
                ],
              ),
          ],
        ),

        // GPS status overlay
        if (!_hasValidGPS && widget.telemetry != null)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_off, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waiting for GPS Signal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Showing Saida, Lebanon',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.telemetry!.lat == 0 && widget.telemetry!.lon == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'GPS: (0,0)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Recenter button
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.small(
            onPressed: recenter,
            backgroundColor: Colors.white,
            child: Icon(
              _hasValidGPS ? Icons.my_location : Icons.location_city,
              color: _hasValidGPS ? Colors.blue : Colors.orange,
            ),
          ),
        ),
      ],
    );
  }
}