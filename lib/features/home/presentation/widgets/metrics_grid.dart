import 'package:flutter/material.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

class MetricsGrid extends StatelessWidget {
  final Telemetry? telemetry;
  const MetricsGrid({super.key, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final t = telemetry;

    final hr = t?.heartRate;
    final gps = t == null
        ? '--'
        : '${t.latitude.toStringAsFixed(5)}, ${t.longitude.toStringAsFixed(5)}';
    final crash = (t?.crashFlag ?? false) ? 'YES' : 'NO';

    final ax = t?.ax;
    final ay = t?.ay;
    final az = t?.az;

    final gforce = (ax == null && ay == null && az == null)
        ? '--'
        : 'ax:${ax?.toStringAsFixed(2) ?? '--'}  '
          'ay:${ay?.toStringAsFixed(2) ?? '--'}  '
          'az:${az?.toStringAsFixed(2) ?? '--'}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          _Card(icon: Icons.favorite, title: 'Heart Rate', value: hr == null ? '--' : '$hr bpm'),
          _Card(icon: Icons.my_location, title: 'GPS', value: gps),
          _Card(icon: Icons.warning_amber_rounded, title: 'Crash', value: crash),
          _Card(icon: Icons.speed, title: 'G-Force (Accel)', value: gforce),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _Card({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00D1FF)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
