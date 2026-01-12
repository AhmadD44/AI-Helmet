import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:isd/features/home/presentation/widgets/telemetry.dart';
import 'package:sms_sender/sms_sender.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CrashAlertPage extends StatefulWidget {
  final RiskData riskData;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const CrashAlertPage({
    super.key,
    required this.riskData,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<CrashAlertPage> createState() => _CrashAlertPageState();
}

class _CrashAlertPageState extends State<CrashAlertPage> {
  Timer? _autoSendTimer;
  Timer? _fallbackTimer;
  bool _handled = false;

  @override
  void initState() {
    super.initState();

    debugPrint('[CrashAlert] Dialog opened');

    _autoSendTimer = Timer(const Duration(seconds: 10), () async {
      if (_handled) return;
      _handled = true;

      debugPrint('[CrashAlert] AUTO MODE');
      await sendLocationToEmergencyContacts(auto: true);

      if (!mounted) return;
      widget.onConfirm();
      Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    debugPrint('[CrashAlert] Disposed');
    _autoSendTimer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }
  String normalizeLebaneseNumber(String raw) {
    String phone = raw.replaceAll(RegExp(r'\s+'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('0')) phone = phone.substring(1);
    if (!phone.startsWith('961')) phone = '961$phone';
    return phone;
  }

  String? safeToString(dynamic v) => v == null ? null : v.toString();

  Future<void> sendLocationToEmergencyContacts({bool auto = false}) async {
    try {
      Location location = Location();

      bool enabled = await location.serviceEnabled();
      if (!enabled && !await location.requestService()) return;

      PermissionStatus perm = await location.hasPermission();
      if (perm == PermissionStatus.denied &&
          await location.requestPermission() != PermissionStatus.granted) return;

      final loc = await location.getLocation();
      if (loc.latitude == null || loc.longitude == null) return;

      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}';

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final contacts = [
        safeToString(doc.data()?['contact1']),
        safeToString(doc.data()?['contact2']),
      ]
          .where((e) => e != null && e.trim().isNotEmpty)
          .map((e) => normalizeLebaneseNumber(e!))
          .toList();

      if (contacts.isEmpty) return;

      final message =
          '🚨 EMERGENCY ALERT 🚨\n'
          'Possible accident detected.\n\n'
          '📍 Location:\n$mapsUrl';

      if (auto) {
         sendSms(contacts, message);
        debugPrint('[CrashAlert] Auto SMS sent');
        return;
      }

      for (final phone in contacts) {
        final uri = Uri.parse(
          'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await Future.delayed(const Duration(seconds: 1));
      }

      _fallbackTimer = Timer(const Duration(seconds: 10), () async {
        debugPrint('[CrashAlert] WhatsApp ignored → SMS fallback');
        sendSms(contacts, message);
      });
    } catch (e, s) {
      debugPrint('[CrashAlert] ERROR: $e\n$s');
    }
  }

  Future<void> sendSms(List<String> phoneNumbers, String message) async {
  for (final phone in phoneNumbers) {
    final uri = Uri.parse(
      'sms:$phone?body=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('❌ Could not open SMS app for $phone');
    }

    await Future.delayed(const Duration(milliseconds: 300));
  }
}

  void _handleCancel() {
    if (_handled) return;
    _handled = true;
    _autoSendTimer?.cancel();
    _fallbackTimer?.cancel();
    widget.onCancel();
    Navigator.of(context).maybePop();
  }

  Future<void> _handleSend() async {
    if (_handled) return;
    _handled = true;
    _autoSendTimer?.cancel();
    await sendLocationToEmergencyContacts();
    widget.onConfirm();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Crash Detected', style: TextStyle(color: Colors.white)),
      content: const Text(
        'If you do nothing, emergency SMS will be sent automatically.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(onPressed: _handleCancel, child: const Text('Cancel')),
        ElevatedButton(onPressed: _handleSend, child: const Text('Send Now')),
      ],
    );
  }
}
