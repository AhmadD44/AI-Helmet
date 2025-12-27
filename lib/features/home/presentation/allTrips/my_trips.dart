import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isd/features/home/data/models/my_trips_model/all_trips_model.dart';
import 'package:isd/features/home/presentation/view_model/all_trips_cubit/all_trips_cubit.dart';
import 'package:isd/features/home/presentation/view_model/all_trips_cubit/all_trips_state.dart';


class MyTripsPage extends StatefulWidget {
  const MyTripsPage({super.key});

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> {

@override
void initState() {
  super.initState();
  context.read<AllTripsCubit>().fetchAllTrips();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        centerTitle: true,
      ),
      body: BlocBuilder<AllTripsCubit, AllTripsState>(
        builder: (context, state) {
          
          final trips;
          if (state is AllTripsFailure) {
            
            trips = [];
            
            return _TripsError(message: state.errMessage);
          }else if (state is AllTripsSuccess) {
            
           trips = state.trips;
          }else {
           trips = [];
            
            return const _TripsLoading();
          }

          if (trips.isEmpty) {
            return const _TripsEmpty();
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                _TripsHeader(count: trips.length),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _TripCard(trip: trips[i]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ------------------------------ Header ------------------------------ */

class _TripsHeader extends StatelessWidget {
  final int count;
  const _TripsHeader({required this.count});

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
      child: Row(
        children: [
          const Icon(Icons.route, color: Color(0xFF00D1FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your Trips',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
            ),
          ),
          _Pill(
            text: '$count',
            icon: Icons.list_alt,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ Trip Card ------------------------------ */

class _TripCard extends StatelessWidget {
  final AllTripsModel trip; // ✅ your model type
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF101A2E);

    // ✅ Map status to a pill
    final s = (trip.status ?? '').toLowerCase().trim();
    final statusUi = _statusStyle(s);

    // ✅ Safe date formatting (no intl package needed)
    final startText = _fmtDateTime(trip.startTime);
    final endText = _fmtDateTime(trip.endTime);

    // ✅ Units (adjust if backend uses meters/km)
    final dist = trip.totalDistance;
    final speed = trip.averageSpeed;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // UI only for now: you can navigate to Trip Details later
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip ${trip.tripId ?? ''} details soon')),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusUi.borderColor, width: statusUi.borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
            if (statusUi.glowColor != null)
              BoxShadow(
                color: statusUi.glowColor!.withOpacity(0.20),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: trip id + status pill
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.tripId ?? 'Trip',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                _Pill(
                  text: statusUi.label,
                  icon: statusUi.icon,
                  color: statusUi.color,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Device ID line
            Row(
              children: [
                const Icon(Icons.memory, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Device: ${trip.deviceId ?? '--'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Time row chips
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(icon: Icons.play_arrow, label: startText ?? '--'),
                _InfoChip(icon: Icons.flag, label: endText ?? '--'),
              ],
            ),

            const SizedBox(height: 12),

            // Stats chips
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                  icon: Icons.straighten,
                  label: dist == null ? '--' : '${dist.toStringAsFixed(1)} km',
                ),
                _InfoChip(
                  icon: Icons.speed,
                  label: speed == null ? '--' : '${speed.toStringAsFixed(1)} km/h',
                ),
              ],
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trip details screen coming soon')),
                  );
                },
                icon: const Icon(Icons.chevron_right),
                label: const Text('View details'),
              ),
            )
          ],
        ),
      ),
    );
  }

  _StatusUi _statusStyle(String status) {
    // You can customize based on backend values:
    // example: "completed", "in_progress", "cancelled", "crashed"
    if (status.contains('crash')) {
      return const _StatusUi(
        label: 'Crash',
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFFF3B30),
        borderColor: Color(0xFFFF3B30),
        borderWidth: 1.6,
        glowColor: Color(0xFFFF3B30),
      );
    }
    if (status.contains('complete')) {
      return const _StatusUi(
        label: 'Completed',
        icon: Icons.check_circle,
        color: Color(0xFF00D1FF),
        borderColor: Color(0x1FFFFFFF),
        borderWidth: 1.0,
        glowColor: null,
      );
    }
    if (status.contains('progress') || status.contains('active') || status.contains('running')) {
      return const _StatusUi(
        label: 'In progress',
        icon: Icons.timelapse,
        color: Colors.white70,
        borderColor: Color(0x1FFFFFFF),
        borderWidth: 1.0,
        glowColor: null,
      );
    }
    if (status.contains('cancel')) {
      return const _StatusUi(
        label: 'Cancelled',
        icon: Icons.cancel,
        color: Color(0xFFFF3B30),
        borderColor: Color(0x1FFFFFFF),
        borderWidth: 1.0,
        glowColor: null,
      );
    }
    return const _StatusUi(
      label: 'Unknown',
      icon: Icons.help_outline,
      color: Colors.white70,
      borderColor: Color(0x1FFFFFFF),
      borderWidth: 1.0,
      glowColor: null,
    );
  }

  String? _fmtDateTime(DateTime? dt) {
    if (dt == null) return null;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }
}

class _StatusUi {
  final String label;
  final IconData icon;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final Color? glowColor;

  const _StatusUi({
    required this.label,
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.glowColor,
  });
}

/* ------------------------------ Loading / Empty / Error ------------------------------ */

class _TripsLoading extends StatelessWidget {
  const _TripsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _TripsEmpty extends StatelessWidget {
  const _TripsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No trips yet.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _TripsError extends StatelessWidget {
  final String message;
  const _TripsError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFFF3B30),
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/* ------------------------------ Chips / Pills ------------------------------ */

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _Pill({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
