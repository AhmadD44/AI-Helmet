import 'package:flutter/material.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';

class MetricsGrid extends StatelessWidget {
  final Telemetry? telemetry;

  const MetricsGrid({super.key, required this.telemetry});

  String _fmtDouble(double? v, {int frac = 1, String fallback = '--'}) {
    if (v == null) return fallback;
    return v.toStringAsFixed(frac);
  }

  @override
  Widget build(BuildContext context) {
    final t = telemetry;
    final speedKmh = (t?.speedMps ?? 0) * 3.6;

    final items = <_MetricCardData>[
      _MetricCardData(
        title: 'Heart Rate',
        value: (t?.heartRate?.toString() ?? '--'),
        unit: 'bpm',
        icon: Icons.favorite,
      ),
      _MetricCardData(
        title: 'Speed',
        value: _fmtDouble(speedKmh, frac: 1),
        unit: 'km/h',
        icon: Icons.speed,
      ),
      _MetricCardData(
        title: 'Altitude',
        value: _fmtDouble(t?.altitude, frac: 0),
        unit: 'm',
        icon: Icons.landscape,
      ),
      _MetricCardData(
        title: 'Heading',
        value: _fmtDouble(t?.bearing, frac: 0),
        unit: '°',
        icon: Icons.explore,
      ),
      _MetricCardData(
        title: 'GPS Accuracy',
        value: _fmtDouble(t?.accuracy, frac: 0),
        unit: 'm',
        icon: Icons.gps_fixed,
      ),
      _MetricCardData(
        title: 'Latitude/Longitude',
        value: (t == null) ? '--' : '${t.latitude.toStringAsFixed(5)}\n${t.longitude.toStringAsFixed(5)}',
        unit: '',
        icon: Icons.place,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, i) => _MetricCard(data: items[i]),
      ),
    );
  }
}

class _MetricCardData {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  _MetricCardData({required this.title, required this.value, required this.unit, required this.icon});
}

class _MetricCard extends StatelessWidget {
  final _MetricCardData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.12),
            theme.colorScheme.secondary.withOpacity(0.08),
          ],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            spreadRadius: -6,
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, size: 24),
            const Spacer(),
            Text(
              data.value.isEmpty ? '--' : '${data.value} ${data.unit}',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              data.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
