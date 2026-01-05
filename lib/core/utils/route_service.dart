import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlng;

class RouteService {
  final String _osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';

  Future<List<latlng.LatLng>> getRoute({
    required latlng.LatLng start,
    required latlng.LatLng end,
  }) async {
    try {
      final url = '$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final geometry = data['routes'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;
        
        // Convert coordinates to latlng.LatLng objects
        return coordinates.map((coord) {
          return latlng.LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();
      }
    } catch (e) {
      print('❌ Routing error: $e');
    }
    
    // Fallback: straight line if routing fails
    return [start, end];
  }
  
  // Calculate total distance and duration
  Future<Map<String, dynamic>> getRouteInfo({
    required latlng.LatLng start,
    required latlng.LatLng end,
  }) async {
    try {
      final url = '$_osrmBaseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=false';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        
        return {
          'distance': route['distance'], // in meters
          'duration': route['duration'], // in seconds
        };
      }
    } catch (e) {
      print('❌ Route info error: $e');
    }
    
    return {'distance': 0, 'duration': 0};
  }
}