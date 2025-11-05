import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';


class MapView extends StatefulWidget {
  final Telemetry? telemetry;

  const MapView({super.key, required this.telemetry});

  @override
  MapViewState createState() => MapViewState();
  
}

class MapViewState extends State<MapView> {
  final Completer<GoogleMapController> _controller = Completer();
  bool _centeredOnce = false;

  static const _fallback = CameraPosition(
    target: LatLng(33.8938, 35.5018), // Beirut
    zoom: 14.5,
  );

  @override
  Widget build(BuildContext context) {
    final t = widget.telemetry;
    final LatLng? me = (t == null) ? null : LatLng(t.latitude, t.longitude);

    final markers = me == null
        ? <Marker>{}
        : {
            Marker(
              markerId: const MarkerId('me'),
              position: me,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          };

    final circles = (me == null || (t?.accuracy ?? 0) <= 0)
        ? <Circle>{}
        : {
            Circle(
              circleId: const CircleId('acc'),
              center: me,
              radius: t!.accuracy!,
              fillColor: Colors.blue.withOpacity(0.15),
              strokeWidth: 0,
            ),
          };

    _maybeCenter(me, t?.bearing);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: GoogleMap(
        initialCameraPosition: _fallback,
        onMapCreated: (c) => _controller.complete(c),
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: true,
        markers: markers,
        circles: circles,
        mapToolbarEnabled: false,
      ),
    );
  }

  Future<void> _maybeCenter(LatLng? me, double? bearing) async {
    if (me == null) return;
    final controller = await _controller.future;
    if (!_centeredOnce) {
      _centeredOnce = true;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: me, zoom: 16, bearing: bearing ?? 0),
        ),
      );
    }
  }

  Future<void> recenter() async {
    final t = widget.telemetry;
    if (t == null) return;
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(t.latitude, t.longitude),
          zoom: 17,
          bearing: t.bearing ?? 0,
          tilt: 40,
        ),
      ),
    );
  }
}
