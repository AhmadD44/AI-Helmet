import 'dart:async';
import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';

class SelectEspDevicePage extends StatefulWidget {
  const SelectEspDevicePage({super.key});

  @override
  State<SelectEspDevicePage> createState() => _SelectEspDevicePageState();
}

class _SelectEspDevicePageState extends State<SelectEspDevicePage> {
  final BluetoothClassic _bt = BluetoothClassic();

  final List<Device> _devices = [];
  StreamSubscription<Device>? _scanSub;

  bool _scanning = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _initAndScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _initAndScan() async {
    try {
      await _bt.initPermissions();
      await _startScan();
    } catch (e) {
      setState(() => _err = e.toString());
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _scanning = true;
      _err = null;
    });

    _scanSub?.cancel();
    _scanSub = _bt.onDeviceDiscovered().listen((d) {
      final exists = _devices.any((x) => x.address == d.address);
      if (!exists) setState(() => _devices.add(d));
    });

    await _bt.startScan();

    // auto stop after 8 seconds
    Future.delayed(const Duration(seconds: 8), () async {
      if (!mounted) return;
      if (_scanning) await _stopScan();
    });
  }

  Future<void> _stopScan() async {
    await _bt.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;

    if (!mounted) return;
    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select ESP Device'),
        actions: [
          IconButton(
            tooltip: _scanning ? 'Stop' : 'Scan',
            icon: Icon(_scanning ? Icons.stop : Icons.refresh),
            onPressed: () async {
              if (_scanning) {
                await _stopScan();
              } else {
                await _startScan();
              }
            },
          )
        ],
      ),
      body: _err != null
          ? Center(child: Text('Error: $_err'))
          : Column(
              children: [
                if (_scanning) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: _devices.isEmpty
                      ? const Center(
                          child: Text(
                            'No devices found.\nMake sure Bluetooth is ON and ESP is discoverable.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: _devices.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d = _devices[i];
                            final name = (d.name?.isNotEmpty ?? false)
                                ? d.name!
                                : 'Unknown';
                            return ListTile(
                              leading: const Icon(Icons.bluetooth_searching),
                              title: Text(name),
                              subtitle: Text(d.address),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await _stopScan();
                                Navigator.pop(context, d.address); // ✅ return MAC
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
