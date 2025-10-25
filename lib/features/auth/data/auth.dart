import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

class Auth {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signUp(
    String email,
    String password,
    BuildContext context,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.',style: TextStyle(color: Colors.white),),
            duration: Duration(seconds: 3),
            backgroundColor: const Color(0xFF00D1FF),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(context, e.message);
    } catch (e) {
      _showErrorSnackBar(context, 'An unexpected error occurred');
    }
  }

  Future<void> signIn(
    String email,
    String password,
    BuildContext context,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await _auth.signOut(); // Optional: Sign them out immediately
        _showErrorSnackBar(context, "Please verify your email before signing in.");
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Signed in successfully!',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: const Color(0xFF00D1FF),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(context, e.message);
    } catch (e) {
      _showErrorSnackBar(context, 'An unexpected error occurred');
    }
  }

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
      _showErrorSnackBar(context, e.message);
    } catch (e) {
      _showErrorSnackBar(context, 'An unexpected error occurred');
    }
  }

  void _showErrorSnackBar(BuildContext context, String? message) {
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
