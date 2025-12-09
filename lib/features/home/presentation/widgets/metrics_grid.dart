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
        'Heart Rate',
        (t?.heartRate?.toString() ?? '--'),
        'bpm',
        Icons.favorite,
      ),
      _MetricCardData(
        'Speed',
        _fmtDouble(speedKmh, frac: 1),
        'km/h',
        Icons.speed,
      ),
      _MetricCardData(
        'Altitude',
        _fmtDouble(t?.altitude, frac: 0),
        'm',
        Icons.landscape,
      ),
      _MetricCardData(
        'Heading',
        _fmtDouble(t?.bearing, frac: 0),
        '°',
        Icons.explore,
      ),
      _MetricCardData(
        'GPS Accuracy',
        _fmtDouble(t?.accuracy, frac: 0),
        'm',
        Icons.gps_fixed,
      ),
      _MetricCardData(
        'Latitude/Longitude',
        (t == null)
            ? '--'
            : '${t.latitude.toStringAsFixed(5)}\n${t.longitude.toStringAsFixed(5)}',
        '',
        Icons.place,
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
  final String title, value, unit;
  final IconData icon;
  _MetricCardData(this.title, this.value, this.unit, this.icon);
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
          ),
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
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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
