import 'package:flutter/material.dart';
import 'package:isd/features/auth/data/auth.dart';
import 'package:isd/features/auth/presentation/view/signup.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
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
                Icon(Icons.pedal_bike_rounded,
                    color: Theme.of(context).colorScheme.secondary, size: 90),
                const SizedBox(height: 12),
                const Text(
                  "AI Helmet",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Welcome back, Rider!",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 32),

                // Email
                TextField(
                  controller: _emailController,
                  decoration: aiInputDecoration("Email", Icons.email_outlined),
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

                ElevatedButton(
                  onPressed: () async{
                    // TODO: implement your sign-in logic
                    await Auth().signIn(_emailController.text, _passwordController.text, context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Center(child: Text("Sign In")),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    );
                  },
                  child: const Text("Don’t have an account? Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
