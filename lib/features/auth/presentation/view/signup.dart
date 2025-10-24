import 'package:flutter/material.dart';
import 'package:isd/features/auth/presentation/view/signin.dart';
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _contact1Controller = TextEditingController();
  final _contact2Controller = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  InputDecoration aiInputDecoration(String hint, IconData icon) {
    const borderColor = Color(0xFF00D1FF);
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: borderColor),
      filled: true,
      fillColor: const Color(0xFF1B2236),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 2),
      ),
      hintStyle: const TextStyle(color: Colors.white54),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sensors_rounded,
                    color: Theme.of(context).colorScheme.secondary, size: 90),
                const SizedBox(height: 12),
                const Text(
                  "Join AI Helmet",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Ride smarter, safer, and connected.",
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Full name
                TextField(
                  controller: _nameController,
                  decoration:
                      aiInputDecoration("Full Name", Icons.person_outline),
                ),
                const SizedBox(height: 16),

                // Emergency contact 1
                TextField(
                  controller: _contact1Controller,
                  decoration:
                      aiInputDecoration("Suggested Emergency contact 1", Icons.person_2_outlined),
                ),
                const SizedBox(height: 16),

                // Emergency contact 2
                TextField(
                  controller: _contact2Controller,
                  decoration:
                      aiInputDecoration("Suggested Emergency contact 2", Icons.person_2_outlined),
                ),
                const SizedBox(height: 16),

                // Email
                TextField(
                  controller: _emailController,
                  decoration:
                      aiInputDecoration("Email", Icons.email_outlined),
                ),
                const SizedBox(height: 16),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration:
                      aiInputDecoration("Password", Icons.lock_outline),
                ),
                const SizedBox(height: 24),

                // Phone Number
                TextField(
                  controller: _phoneController,
                  decoration:
                      aiInputDecoration("Phone Number", Icons.phone),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () {
                    // TODO: implement your sign-up logic
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Center(child: Text("Create Account")),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignInScreen(),
                      ),
                    );
                  },
                  child: const Text("Already have an account? Sign In"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
