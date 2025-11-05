import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:isd/features/home/presentation/widgets/telemetry_cubit.dart';
import 'package:isd/features/home/presentation/widgets/map_view.dart';
import 'package:isd/features/home/presentation/widgets/metrics_grid.dart';
import 'package:isd/features/home/presentation/widgets/drawer.dart';
import 'package:isd/features/home/presentation/widgets/about_us.dart';
import 'package:isd/features/home/presentation/widgets/faq.dart';


class HomeScreen extends StatefulWidget {
  final Future<void> Function()? onSignOut;
  const HomeScreen({super.key, this.onSignOut});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Important: in map_view.dart, expose public state `MapViewState` with recenter()
  final GlobalKey<MapViewState> _mapKey = GlobalKey<MapViewState>();

  @override
  void initState() {
    super.initState();
    // Start polling via TelemetryCubit
    // context.read<TelemetryCubit>().start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onAbout: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AboutUsPage()),
        ),
        onFaq: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FaqPage()),
        ),
        onSignOut: widget.onSignOut,
      ),
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Recenter',
            onPressed: () => _mapKey.currentState?.recenter(),
            icon: const Icon(Icons.my_location),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= 900;
          return BlocBuilder<TelemetryCubit, TelemetryState>(
            builder: (context, state) {
              final map = MapView(key: _mapKey, telemetry: state.data);
              final metrics = MetricsGrid(telemetry: state.data);

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: map),
                    Expanded(flex: 2, child: metrics),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(flex: 5, child: map),
                  Expanded(flex: 5, child: metrics),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mapKey.currentState?.recenter(),
        icon: const Icon(Icons.near_me),
        label: const Text('Recenter'),
      ),
    );
  }
}
