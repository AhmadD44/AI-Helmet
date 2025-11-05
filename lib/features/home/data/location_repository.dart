import 'dart:async';
// import 'package:isd/core/network/api_consumer.dart'; // adjust import to your ApiConsumer path
import 'package:isd/core/network/fake_api_consumer.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

class LocationRepository {
  final FakeApiConsumer api;
  final Duration interval;
  final String endpoint;

  Timer? _timer;
  final _controller = StreamController<Telemetry>.broadcast();
  bool _running = false;

  LocationRepository({
    required this.api,
    this.interval = const Duration(milliseconds: 200),
    this.endpoint = '/driver/telemetry', // <- change to your endpoint
  });

  Stream<Telemetry> get stream => _controller.stream;

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(interval, (_) async {
      try {
        final res = await api.get(endpoint); // expects Map<String, dynamic>
        // If your API wraps the payload under "data", unwrap it:
        final body = (res is Map<String, dynamic> && res['data'] is Map<String, dynamic>)
            ? res['data'] as Map<String, dynamic>
            : (res as Map<String, dynamic>);
        _controller.add(Telemetry.fromJson(body));
      } catch (e) {
        _controller.addError(e);
      }
    });
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
