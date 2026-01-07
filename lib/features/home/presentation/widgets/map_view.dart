import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

// REMOVE: import 'telemetry.dart'; // No longer needed!

class MapView extends StatefulWidget {
  // REMOVE: final Telemetry? telemetry; // No ESP telemetry in MapView!
  
  // Keep only map/location related properties
  final latlng.LatLng? initialLocation;  // For initial map center
  final latlng.LatLng? destination;
  final bool tripActive;
  final void Function(latlng.LatLng? dest)? onDestinationSelected; // Changed to nullable
  final void Function(bool isTripActive)? onTripStatusChanged;
  final void Function(latlng.LatLng destination)? onTripStarted;
  final void Function(List<latlng.LatLng> routePoints)? onRouteCalculated;
  
  // Add callback for mobile GPS updates (optional, if other components need it)
  final void Function(latlng.LatLng mobileLocation)? onMobileLocationUpdate;

  const MapView({
    super.key,
    this.initialLocation,  // Changed from telemetry
    this.destination,
    this.tripActive = false,
    this.onDestinationSelected,
    this.onTripStatusChanged,
    this.onTripStarted,
    this.onRouteCalculated,
    this.onMobileLocationUpdate,  // New: for mobile GPS updates
  });

  @override
  State<MapView> createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  bool _centeredOnce = false;
  
  // Routing variables
  List<latlng.LatLng> _routePoints = [];
  bool _isCalculatingRoute = false;
  double _routeDistance = 0.0;
  int _routeDuration = 0;
  
  // Location package variables - ONLY FOR MAP/NAVIGATION
  final Location _location = Location();
  LocationData? _currentMobileLocation;
  bool _isMobileGpsAvailable = false;
  bool _isListening = false;
  StreamSubscription<LocationData>? _locationSubscription;

  /// Get current location for MAP DISPLAY ONLY
  latlng.LatLng get _currentLocation {
  // Use ONLY mobile GPS
  if (_currentMobileLocation != null &&
      _currentMobileLocation!.latitude != null &&
      _currentMobileLocation!.longitude != null &&
      _currentMobileLocation!.latitude != 0 &&
      _currentMobileLocation!.longitude != 0) {
    return latlng.LatLng(
      _currentMobileLocation!.latitude!,
      _currentMobileLocation!.longitude!,
    );
  }
  
  // If no valid mobile GPS, use a default location
  // You can change this to your preferred default
  return const latlng.LatLng(33.5631, 35.3689); // Saida, Lebanon
}

  /// Get current GPS source for display
  String get _currentGpsSource {
    return _isMobileGpsAvailable ? "GPS Available" : "No GPS";
  }

  latlng.LatLng get _saidaLocation {
    return const latlng.LatLng(33.5631, 35.3689);
  }

  void recenter() {
  final hasValidMobileGps = _currentMobileLocation != null &&
      _currentMobileLocation!.latitude != null &&
      _currentMobileLocation!.longitude != null &&
      _currentMobileLocation!.latitude != 0.0 &&
      _currentMobileLocation!.longitude != 0.0;
  
  if (hasValidMobileGps) {
    _mapController.move(_currentLocation, 16);
  } else {
    // If no mobile GPS, center on default location
    _mapController.move(const latlng.LatLng(33.5631, 35.3689), 13);
  }
}

  // ROUTING METHODS (unchanged)
  Future<void> _calculateRoute() async {
    if (widget.destination == null) return;
    
    setState(() => _isCalculatingRoute = true);
    
    try {
      final start = _currentLocation;
      final end = widget.destination!;
      
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final geometry = data['routes'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;
        
        _routePoints = coordinates.map((coord) {
          return latlng.LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();
        
        final routeInfo = data['routes'][0];
        _routeDistance = routeInfo['distance'] / 1000;
        _routeDuration = routeInfo['duration'] ~/ 60;
        
        widget.onRouteCalculated?.call(_routePoints);
        
        print('✅ Route calculated: ${_routePoints.length} points');
        print('📏 Distance: ${_routeDistance.toStringAsFixed(1)} km');
        print('⏱️ Duration: $_routeDuration min');
      }
    } catch (e) {
      print('❌ Route calculation failed: $e');
      _routePoints = [_currentLocation, widget.destination!];
    } finally {
      setState(() => _isCalculatingRoute = false);
    }
  }

  // Check if two points are close enough to be considered the same
  bool _isSameLocation(latlng.LatLng point1, latlng.LatLng point2) {
    // Tolerance of 0.0001 degrees (approx 11 meters)
    final latDiff = (point1.latitude - point2.latitude).abs();
    final lngDiff = (point1.longitude - point2.longitude).abs();
    return latDiff < 0.0001 && lngDiff < 0.0001;
  }

  // Handle map tap - toggles destination on/off
  void _handleMapTap(latlng.LatLng point) {
    if (widget.onDestinationSelected != null) {
      // If there's a current destination and user taps near it, remove it
      if (widget.destination != null && _isSameLocation(point, widget.destination!)) {
        widget.onDestinationSelected!(null);
      } else {
        // Otherwise, set the new destination
        widget.onDestinationSelected!(point);
      }
    }
  }

  Future<void> _initMobileGps() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      print('✅ Mobile GPS permission granted');
      
      _currentMobileLocation = await _location.getLocation();
      
      if (!_isListening) {
        _locationSubscription = _location.onLocationChanged.listen(
          (LocationData currentLocation) {
            if (mounted) {
              setState(() {
                _currentMobileLocation = currentLocation;
                _isMobileGpsAvailable = true;
              });
            }
            
            // NOTIFY PARENT ABOUT MOBILE GPS UPDATE (OPTIONAL)
            widget.onMobileLocationUpdate?.call(
              latlng.LatLng(
                currentLocation.latitude!,
                currentLocation.longitude!,
              ),
            );
            
            print('📍 Map using Mobile GPS: ${currentLocation.latitude}, ${currentLocation.longitude}');
          },
          onError: (error) {
            print('❌ Mobile GPS error: $error');
            if (mounted) {
              setState(() {
                _isMobileGpsAvailable = false;
              });
            }
          },
        );
        _isListening = true;
      }
      
    } catch (e) {
      print('⚠️ Mobile GPS initialization error: $e');
    }
  }

  void _stopMobileGpsUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isListening = false;
    print('🛑 Stopped mobile GPS tracking');
  }

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(_saidaLocation, 13);
        _initMobileGps();  // Start mobile GPS for map/navigation
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_centeredOnce && _currentMobileLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        _mapController.move(_currentLocation, 16);
        _centeredOnce = true;
      });
    }
    
    // Calculate route when destination changes
    if (widget.destination != oldWidget.destination) {
      if (widget.destination != null) {
        _calculateRoute();
      } else {
        // Clear route when destination is removed
        _routePoints.clear();
        _routeDistance = 0.0;
        _routeDuration = 0;
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  @override
  void dispose() {
    _stopMobileGpsUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = _currentLocation;
    final initialZoom = _currentMobileLocation != null ? 16.0 : 13.0;
    
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentLocation,
            initialZoom: initialZoom,
            onTap: (tapPosition, point) {
              _handleMapTap(point);
            },
          ),
          children: [
            // 🌍 Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.isd',
              tileProvider: NetworkTileProvider(),
            ),

            // 📍 Current position marker (based on mobile GPS or initial location)
            MarkerLayer(
              markers: [
                Marker(
                  width: 42,
                  height: 42,
                  point: currentLocation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.tripActive ? Colors.green : 
                             _isMobileGpsAvailable ? Colors.blue : Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.tripActive ? Icons.directions_bike : 
                      _isMobileGpsAvailable ? Icons.directions_bike : Icons.location_city,
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
                    width: 50,
                    height: 50,
                    point: widget.destination!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.tripActive ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.tripActive ? Icons.flag : Icons.location_pin,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

            // 🛣️ Blue navigation route (when trip is active)
            if (widget.tripActive && _routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 6,
                    color: Colors.blue.withOpacity(0.8),
                    borderColor: Colors.white,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

            // 📏 Route preview (when not active)
            if (!widget.tripActive && _routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4,
                    color: Colors.blue.withOpacity(0.5),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
          ],
        ),

        // GPS source indicator
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _isMobileGpsAvailable ? Icons.phone_android : Icons.device_hub,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentGpsSource,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Route info overlay
        if (_routePoints.isNotEmpty && !widget.tripActive)
          Positioned(
            top: 80,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.route,
                        size: 16,
                        color: Colors.cyan,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Route Calculated',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_routeDistance.toStringAsFixed(1)} km • $_routeDuration min',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Route calculation loading
        if (_isCalculatingRoute)
          Positioned(
            top: 80,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.cyan),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Calculating route...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Trip status indicator
        if (widget.tripActive)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_bike, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Trip Active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_routeDistance > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${_routeDistance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
              _isMobileGpsAvailable ? Icons.my_location : Icons.location_city,
              color: _isMobileGpsAvailable ? Colors.blue : Colors.orange,
            ),
          ),
        ),

        // Instructions
        if (widget.destination == null)
          Positioned(
            bottom: 150,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.touch_app, size: 32, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap on map to select destination',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Then press "Start Trip"',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}