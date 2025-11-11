import 'package:flutter/material.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

class MapView extends StatefulWidget {
  final Telemetry? telemetry;
  const MapView({super.key, required this.telemetry});

  @override
  MapViewState createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  bool _centeredOnce = false;

  static final latlng.LatLng _fallbackCenter =
      latlng.LatLng(33.8938, 35.5018);

  @override
  Widget build(BuildContext context) {
    final t = widget.telemetry;
    final latlng.LatLng? me =
        (t == null) ? null : latlng.LatLng(t.latitude, t.longitude);

    final markers = <Marker>[
      if (me != null)
        Marker(
          point: me,
          width: 40,
          height: 40,
          // ✅ in flutter_map 7+, use `child:` instead of `builder:`
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
            child: const Icon(
              Icons.pedal_bike,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
    ];

    _maybeCenter(me);

    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _fallbackCenter,
          initialZoom: 14.5,
          minZoom: 3,
          maxZoom: 19,
          keepAlive: true,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.isd',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
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
