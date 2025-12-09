import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

class Auth {
  final FirebaseAuth auth = FirebaseAuth.instance;

  void passReset(String email, BuildContext context) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check your email',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: const Color(0xFF00D1FF),
        ),
      );
    } on FirebaseAuthException catch (e) {
      showErrorSnackBar(context, e.message);
    } catch (e) {
      showErrorSnackBar(context, 'An unexpected error occurred');
    }
  }

  void showErrorSnackBar(BuildContext context, String? message) {
    Flushbar(
      message: message,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      backgroundColor: Colors.red.shade600,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.BOTTOM,
      animationDuration: const Duration(milliseconds: 400),
    ).show(context);
  }
}
