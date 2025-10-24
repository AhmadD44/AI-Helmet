import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:isd/features/auth/presentation/view/signin.dart';
import 'package:isd/firebase_options.dart';

Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
     );
    runApp(const AIHelmetApp());
 }

class AIHelmetApp extends StatelessWidget {
  const AIHelmetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Helmet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0F1C),
        colorScheme: const ColorScheme.dark(
          secondary: Color(0xFF00D1FF),
        ),
      ),
      home: const SignInScreen(),
    );
  }
}
