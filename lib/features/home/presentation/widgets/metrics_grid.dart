import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'telemetry.dart';

class MetricsGrid extends StatelessWidget {
  final Telemetry? telemetry;
  const MetricsGrid({super.key, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final t = telemetry;

    // 1. Heart Rate
    final hr = t?.heart;
    final hrValue = hr == null ? '--' : '$hr bpm';
    
    // 2. GPS Coordinates
    final gpsValue = t == null
        ? '--'
        : '${t.lat.toStringAsFixed(6)}\n${t.lon.toStringAsFixed(6)}';

    // 3. Helmet Status
    final helmetOn = t?.helmetOn ?? false;
    final helmetValue = helmetOn ? 'ON' : 'OFF';
    final helmetColor = helmetOn ? Colors.green : Colors.orange;

    // 4. Velocity/Speed
    final velocity = t?.velocity;
    final speedValue = velocity == null 
        ? '-- km/h' 
        : '${velocity.toStringAsFixed(1)} km/h';

    // 5. Accelerometer (G-Force calculated from ax, ay, az)
    final gForce = _calculateGForce(t?.ax, t?.ay, t?.az);
    final gForceValue = gForce?.toStringAsFixed(2) ?? '--';
    final accelDetails = 'G: $gForceValue g\n'
        'X: ${t?.ax?.toStringAsFixed(2) ?? '--'} m/s²\n'
        'Y: ${t?.ay?.toStringAsFixed(2) ?? '--'} m/s²\n'
        'Z: ${t?.az?.toStringAsFixed(2) ?? '--'} m/s²';

    // 6. Packet Info & Timestamp
    final packetValue = t == null 
        ? '--' 
        : 'Packet #${t.t}\n'
          '${_formatTimestamp(t.ts)}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          // Card 1: Heart Rate
          _Card(
            icon: Icons.favorite,
            title: 'Heart Rate',
            value: hrValue,
            iconColor: Colors.red[400]!,
            subtitle: hr != null ? 'Live' : 'No data',
          ),

          // Card 2: GPS
          _Card(
            icon: Icons.gps_fixed,
            title: 'GPS',
            value: gpsValue,
            iconColor: Colors.blue[400]!,
            subtitle: t != null ? 'Active' : '--',
          ),

          // Card 3: Helmet Status
          _Card(
            icon: helmetOn ? Icons.check_circle_outline : Icons.error_outline,
            title: 'Helmet',
            value: helmetValue,
            iconColor: helmetColor,
            valueColor: helmetColor,
            subtitle: helmetOn ? 'Worn' : 'Not worn',
          ),

          // Card 4: Speed
          _Card(
            icon: Icons.speed_outlined,
            title: 'Speed',
            value: speedValue,
            iconColor: Colors.purple[300]!,
            subtitle: velocity != null ? 'Moving' : 'Stopped',
          ),

          // Card 5: Accelerometer
          _Card(
            icon: Icons.directions_run_outlined,
            title: 'Acceleration',
            value: accelDetails,
            iconColor: Colors.green[400]!,
            subtitle: '3-axis',
          ),

          // Card 6: Packet Info
          _Card(
            icon: Icons.info_outline,
            title: 'Packet Info',
            value: packetValue,
            iconColor: Colors.amber[400]!,
            subtitle: t != null ? 'Latest' : '--',
          ),
        ],
      ),
    );
  }

  // Helper to calculate G-Force from accelerometer data
  double? _calculateGForce(double? ax, double? ay, double? az) {
    if (ax == null || ay == null || az == null) return null;
    // Calculate magnitude (g-force approximation)
    final magnitude = math.sqrt(ax * ax + ay * ay + az * az);
    // Convert m/s² to g (1 g = 9.80665 m/s²)
    return magnitude / 9.80665;
  }

  // Helper to format timestamp
  String _formatTimestamp(int ts) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      return '${date.hour.toString().padLeft(2, '0')}:'
             '${date.minute.toString().padLeft(2, '0')}:'
             '${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid time';
    }
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final Color valueColor;
  final String? subtitle;

  const _Card({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor = Colors.white,
    this.valueColor = Colors.white,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101A2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row: Icon + Title
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          // Subtitle (optional)
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ),
          
          // Main Value
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                  fontSize: value.contains('\n') ? 13 : 16,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}