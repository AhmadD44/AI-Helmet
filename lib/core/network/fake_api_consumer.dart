import 'dart:math';

/// Simulates an API that returns driver telemetry.
class FakeApiConsumer {
  // Beirut starting point
  double _lat = 33.8938;
  double _lng = 35.5018;
  final _rand = Random();

  /// Pretend to call an endpoint
  Future<Map<String, dynamic>> get(String endpoint) async {
    await Future.delayed(const Duration(milliseconds: 50)); // fake network delay

    // Simulate small random movement (~2–3 m) and data
    _lat += (_rand.nextDouble() - 0.5) / 2000;
    _lng += (_rand.nextDouble() - 0.5) / 2000;

    final double speedMps = 5 + _rand.nextDouble() * 2; // 5–7 m/s (~18–25 km/h)
    final double bearing = _rand.nextDouble() * 360;

    return {
      'latitude': _lat,
      'longitude': _lng,
      'speed_mps': speedMps,
      'bearing': bearing,
      'altitude': 50 + _rand.nextDouble() * 5,
      'accuracy': 3 + _rand.nextDouble() * 2,
      'heart_rate': 70 + _rand.nextInt(30),
    };
  }
}
