import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'telemetry.dart';
import 'telemetry_cubit.dart';

class MetricsGrid extends StatelessWidget {
  final Telemetry? telemetry;
  const MetricsGrid({super.key, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final t = telemetry;

    final heartRate = t?.heartRate;
    final hr = heartRate?.hr;
    final hrValue = hr == null ? '--' : '$hr bpm';
    final spo2 = heartRate?.spo2;
    final spo2Value = spo2 == null ? '--' : '$spo2%';
    final fingerDetected = heartRate?.finger ?? false;
    
    final gps = t?.gps;
    final gpsValue = (gps == null || !gps.lock)
    ? '--'
    : '${gps.lat.toStringAsFixed(6)}\n${gps.lng.toStringAsFixed(6)}';
    final gpsLock = gps?.lock ?? false;
    final satellites = gps?.sats ?? 0;

    final helmetOn = t?.helmetOn ?? false;
    final helmetValue = helmetOn ? 'ON' : 'OFF';
    final helmetColor = helmetOn ? Colors.green : Colors.orange;

    final velocity = t?.speed;
    final speedValue = velocity == null 
        ? '-- km/h' 
        : '${velocity.toStringAsFixed(1)} km/h';

    final gForce = _calculateGForce(t?.ax, t?.ay, t?.az);
    final gForceValue = gForce?.toStringAsFixed(2) ?? '--';
    final accelDetails = 'G: $gForceValue g\n'
        'X: ${t?.ax?.toStringAsFixed(2) ?? '--'} m/s²\n'
        'Y: ${t?.ay?.toStringAsFixed(2) ?? '--'} m/s²\n'
        'Z: ${t?.az?.toStringAsFixed(2) ?? '--'} m/s²';

    final gyroDetails = t?.imu?.ok == true
        ? 'X: ${t?.gx?.toStringAsFixed(2) ?? '--'}°/s\n'
          'Y: ${t?.gy?.toStringAsFixed(2) ?? '--'}°/s\n'
          'Z: ${t?.gz?.toStringAsFixed(2) ?? '--'}°/s'
        : 'No gyro data';

    final deviceId = t?.deviceId ?? '--';
    final timestamp = _formatTimestamp(t?.ts ?? 0);

    return BlocBuilder<TelemetryCubit, TelemetryState>(
      builder: (context, state) {
        final currentRisk = state.currentRisk;
        
        final riskValue = currentRisk != null
            ? ' ${currentRisk.level}\n'
            : 'No risk data';
        
        final riskColor = currentRisk?.color ?? Colors.grey;
        final riskReasons = currentRisk?.reasons ?? [];

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
              _Card(
                icon: Icons.favorite,
                title: 'Heart Rate',
                value: hrValue,
                iconColor: Colors.red[400]!,
                subtitle: fingerDetected ? 'Finger detected' : 'No finger',
                badge: spo2 != null 
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getSpo2Color(spo2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'SpO2: $spo2%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),


              _Card(
                icon: Icons.shield_outlined,
                title: 'Risk Status',
                value: riskValue,
                iconColor: riskColor,
                valueColor: riskColor,
                subtitle: riskReasons.isNotEmpty 
                    ? riskReasons.join(', ')
                    : 'No issues',
                badge: currentRisk != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: riskColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          currentRisk.level,
                          style: TextStyle(
                            color: riskColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),

              _Card(
                icon: helmetOn ? Icons.check_circle_outline : Icons.error_outline,
                title: 'Helmet',
                value: helmetValue,
                iconColor: helmetColor,
                valueColor: helmetColor,
                subtitle: helmetOn ? 'Worn properly' : 'Not worn',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: helmetOn ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: helmetOn ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    helmetOn ? 'SAFE' : 'WARNING',
                    style: TextStyle(
                      color: helmetOn ? Colors.green : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              _Card(
                icon: Icons.speed_outlined,
                title: 'Speed',
                value: speedValue,
                iconColor: velocity != null && velocity > 0 
                    ? Colors.purple[300]! 
                    : Colors.grey[400]!,
                subtitle: velocity != null && velocity > 0 
                    ? 'Moving' 
                    : 'Stopped',
                badge: velocity != null && velocity > 10
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'FAST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),

              _Card(
                icon: Icons.directions_run_outlined,
                title: 'Acceleration',
                value: accelDetails,
                iconColor: Colors.green[400]!,
                subtitle: 'G-Force: $gForceValue g',
              ),

              _Card(
                icon: Icons.cached,
                title: 'Gyroscope',
                value: gyroDetails,
                iconColor: Colors.blue[400]!,
                subtitle: 'Rotation rate',
              ),

              _Card(
                icon: Icons.device_hub,
                title: 'Device',
                value: deviceId,
                iconColor: Colors.amber[400]!,
                subtitle: 'Helmet ID',
              ),

              _Card(
                icon: Icons.access_time,
                title: 'Last Update',
                value: timestamp,
                iconColor: Colors.cyan[400]!,
                subtitle: 'Time received',
              ),

              _Card(
                icon: gpsLock ? Icons.gps_fixed : Icons.gps_off,
                title: 'GPS',
                value: gpsValue,
                iconColor: gpsLock ? Colors.green[400]! : Colors.grey[400]!,
                subtitle: gpsLock 
                    ? '${satellites} satellites'
                    : 'No signal',
                badge: gpsLock
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'LOCKED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
              
            ],
          ),
        );
      },
    );
  }

  double? _calculateGForce(double? ax, double? ay, double? az) {
    if (ax == null || ay == null || az == null) return null;
    final magnitude = math.sqrt(ax * ax + ay * ay + az * az);
    return magnitude / 9.80665;
  }

  String _formatTimestamp(int ts) {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
           '${now.minute.toString().padLeft(2, '0')}:'
           '${now.second.toString().padLeft(2, '0')}';
  }
  
  Color _getSpo2Color(int spo2) {
    if (spo2 >= 95) return Colors.green;
    if (spo2 >= 90) return Colors.orange;
    return Colors.red;
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final Color valueColor;
  final String? subtitle;
  final Widget? badge;

  const _Card({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor = Colors.white,
    this.valueColor = Colors.white,
    this.subtitle,
    this.badge,
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
              if (badge != null) badge!,
            ],
          ),
          
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