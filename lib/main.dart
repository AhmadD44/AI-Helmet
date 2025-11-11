import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:isd/features/auth/presentation/view/signin.dart';
import 'package:isd/features/auth/presentation/view_model/login/login_cubit.dart';
import 'package:isd/features/auth/presentation/view_model/signup/signup_cubit.dart';
import 'package:isd/firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isd/features/home/presentation/widgets/telemetry_cubit.dart';
import 'package:isd/features/home/presentation/home_Screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(AIHelmetApp());
}

class AIHelmetApp extends StatelessWidget {
  const AIHelmetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LoginCubit>(create: (context) => LoginCubit()),
        BlocProvider<SignupCubit>(create: (context) => SignupCubit()),
        BlocProvider<TelemetryCubit>(
          create: (_) => TelemetryCubit()..start(), // ✅ starts GPS here
          child: MaterialApp(home: const HomeScreen()),
        ),
      ],
      child: MaterialApp(
        title: 'AI Helmet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0A0F1C),
          colorScheme: const ColorScheme.dark(secondary: Color(0xFF00D1FF)),
        ),
        home: const SignInScreen(),
      ),
    );
  }
}
