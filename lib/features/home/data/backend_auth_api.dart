import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendAuthApi {
  final String baseUrl; // e.g. http://192.168.1.10:8000
  BackendAuthApi(this.baseUrl);

  Future<void> ensureUserAndDevice({
    required String firebaseIdToken,
    required String deviceId,
  }) async {
    // 1) verify user
    final me = await http.get(
      Uri.parse('$baseUrl/api/v1/users/me'),
      headers: {'Authorization': 'Bearer $firebaseIdToken'},
    );
    if (me.statusCode >= 400) {
      throw Exception('users/me failed: ${me.statusCode} ${me.body}');
    }

    // 2) register device (same as python)
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/devices'),
      headers: {
        'Authorization': 'Bearer $firebaseIdToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'device_id': deviceId,
        'model_name': 'Helmet v1',
      }),
    );

    // if your backend returns 409 when device already exists, you can treat as ok
    if (res.statusCode >= 400 && res.statusCode != 409) {
      throw Exception('devices failed: ${res.statusCode} ${res.body}');
    }
  }
}
