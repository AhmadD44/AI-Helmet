import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'We are a cutting-edge technology company specializing in AI-powered helmets designed to enhance rider safety. '
            'Our innovative helmets detect accidents in real-time and can automatically alert emergency services, '
            'ensuring faster response and potentially saving lives. '
            'Driven by safety, intelligence, and reliability, we aim to redefine the way riders protect themselves on the road.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}