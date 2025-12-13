import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

class MetricsGrid extends StatelessWidget {
  final Telemetry? telemetry;
  const MetricsGrid({super.key, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final t = telemetry;

    final hr = t?.heartRate;
    final crash = t?.crashFlag;

    final lat = t?.latitude;
    final lng = t?.longitude;

    final gForce = _computeGForce(t);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _MetricCard(
            title: 'Heart Rate',
            value: hr == null ? '--' : '$hr',
            unit: 'BPM',
            icon: Icons.favorite,
          ),
          _MetricCard(
            title: 'Crash Status',
            value: crash == null ? '--' : (crash ? 'CRASH' : 'SAFE'),
            unit: '',
            icon: crash == true ? Icons.warning_amber_rounded : Icons.verified,
            emphasis: crash == true,
          ),
          _MetricCard(
            title: 'GPS Location',
            value: (lat == null || lng == null)
                ? '--'
                : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            unit: '',
            icon: Icons.location_on,
          ),
          _MetricCard(
            title: 'G-Force',
            value: gForce == null ? '--' : gForce.toStringAsFixed(2),
            unit: 'g',
            icon: Icons.speed,
          ),
        ],
      ),
    );
  }

  double? _computeGForce(Telemetry? t) {
    final ax = t?.ax, ay = t?.ay, az = t?.az;
    if (ax == null || ay == null || az == null) return null;

    final magnitude = math.sqrt(ax * ax + ay * ay + az * az); // m/s^2
    return magnitude / 9.80665; // convert to g
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final bool emphasis;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = const Color(0xFF101A2E);
    final border = emphasis ? const Color(0xFFFF3B30) : const Color(0x1FFFFFFF);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: emphasis ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: emphasis ? const Color(0xFFFF3B30) : Colors.white,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
        ],
      ),
    );
  }
}
