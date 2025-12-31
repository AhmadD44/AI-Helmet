import 'dart:async';
import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'package:isd/features/home/data/esp_classic_bt_msgpack_source.dart';

class ConnectEspPage extends StatefulWidget {
  final EspBtClassicSource source;
  const ConnectEspPage({super.key, required this.source});

  @override
  State<ConnectEspPage> createState() => _ConnectEspPageState();
}

class _ConnectEspPageState extends State<ConnectEspPage> {
  final List<Device> _devices = [];
  StreamSubscription<Device>? _scanSub;
  bool _scanning = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    widget.source.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _scanning = true;
      _err = null;
    });

    try {
      await _scanSub?.cancel();
      _scanSub = widget.source.onDeviceDiscovered().listen((d) {
        final exists = _devices.any((x) => x.address == d.address);
        if (!exists && mounted) setState(() => _devices.add(d));
      });

      await widget.source.startScan();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _scanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    await widget.source.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Connect ESP"),
        actions: [
          IconButton(
            icon: Icon(_scanning ? Icons.stop : Icons.refresh),
            onPressed: () async {
              if (_scanning) {
                await _stopScan();
              } else {
                await _startScan();
              }
            },
          ),
        ],
      ),
      body: _err != null
          ? Center(child: Text("Error:\n$_err", textAlign: TextAlign.center))
          : Column(
              children: [
                if (_scanning) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView.separated(
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = _devices[i];
                      return ListTile(
                        leading: const Icon(Icons.bluetooth_searching),
                        title: Text((d.name ?? "").isNotEmpty ? d.name! : "Unknown"),
                        subtitle: Text(d.address ?? ""),
                        onTap: () async {
                          await _stopScan();
                          if (!mounted) return;
                          Navigator.pop(context, d.address);
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
