import 'package:flutter/material.dart';
import 'package:isd/features/auth/data/auth.dart';
import 'package:email_validator/email_validator.dart';
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
  bool isloading = false;
  final _formKey = GlobalKey<FormState>();

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
        child: Form(
          key: _formKey,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 90,
                  ),
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
                  TextFormField(
                    controller: _nameController,
                    decoration: aiInputDecoration(
                      "Username",
                      Icons.person_outline,
                    ),
                    validator: (value) {
                      return value!.length < 4
                          ? "Username should be atleast 4 characters"
                          : null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 16),

                  // Emergency contact 1
                  TextFormField(
                    controller: _contact1Controller,
                    decoration: aiInputDecoration(
                      "Suggested Emergency contact 1",
                      Icons.person_2_outlined,
                    ),
                    validator: (value) {
                      return value!.length != 8
                          ? "Enter valid phone number"
                          : null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Emergency contact 2
                  TextFormField(
                    controller: _contact2Controller,
                    decoration: aiInputDecoration(
                      "Suggested Emergency contact 2",
                      Icons.person_2_outlined,
                    ),
                    validator: (value) {
                      return value!.length != 8
                          ? "Enter valid phone number"
                          : null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: aiInputDecoration(
                      "Email",
                      Icons.email_outlined,
                    ),
                    validator: (value) {
                      return value != null && !EmailValidator.validate(value)
                          ? "Enter a valid email"
                          : null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                    obscureText: false,
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: aiInputDecoration(
                      "Password",
                      Icons.lock_outline,
                    ),
                    validator: (value) {
                      return value!.length < 6
                          ? "Enter at least 6 characters"
                          : null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.text,
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),

                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    decoration: aiInputDecoration("Phone Number", Icons.phone),
                    validator: (value) {
                      return value!.length != 8
                          ? "Enter valid phone number"
                          : null;
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      // TODO: implement your sign-up logic
                      if (_formKey.currentState!.validate()) {
                        // setState(() => isloading = true);

                        await Auth().signUp(
                          _emailController.text,
                          _passwordController.text,
                          _nameController.text,
                          int.parse(_contact1Controller.text),
                          int.parse(_contact2Controller.text),
                          int.parse(_phoneController.text),
                          context,
                        );

                        // setState(() => isloading = false);
                      } else {
                        Auth().showErrorSnackBar(context, "Please fill all required feilds");
                      }
                      //  Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => const SignInScreen(),
                      //   ),);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D1FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isloading
                        ? CircularProgressIndicator()
                        : const Center(child: Text("Create Account")),
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
      ),
    );
  }
}
