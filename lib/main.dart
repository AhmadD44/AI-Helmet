// main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:isd/core/utils/service_locator.dart';
import 'package:isd/features/auth/presentation/view/signin.dart';
import 'package:isd/features/auth/presentation/view_model/login/login_cubit.dart';
import 'package:isd/features/auth/presentation/view_model/signup/signup_cubit.dart';
import 'package:isd/features/home/data/esp_classic_bt_msgpack_source.dart';
import 'package:isd/features/home/data/ingest_ws_client.dart';

import 'package:isd/features/home/data/repos/home_repo_impl.dart';
import 'package:isd/features/home/presentation/home_Screen.dart';
import 'package:isd/features/home/presentation/view_model/all_trips_cubit/all_trips_cubit.dart';
import 'package:isd/features/home/presentation/widgets/telemetry_cubit.dart';

import 'package:isd/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  setupServiceLocator();
  runApp(const AIHelmetApp());
}

class AIHelmetApp extends StatelessWidget {
  const AIHelmetApp({super.key});

  @override
  Widget build(BuildContext context) {
    bool signedIn = false;
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // ✅ User already logged in
      signedIn = true;
    } else {
      // ❌ Not logged in
      signedIn = false;
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<LoginCubit>(create: (_) => LoginCubit()),
        BlocProvider<SignupCubit>(create: (_) => SignupCubit()),

        BlocProvider<AllTripsCubit>(
          create: (_) => AllTripsCubit(getIt.get<HomeRepoImpl>()),
        ),

        BlocProvider<TelemetryCubit>(
          create: (_) => TelemetryCubit(
            source: EspBtClassicSource(debugLog: true),
            ingest: IngestWsClient(
              ingestUri: Uri.parse("ws://ec2-3-14-15-242.us-east-2.compute.amazonaws.com:8000/ws/ingest"),
              debugLog: true,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'AI Helmet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0A0F1C),
          colorScheme: const ColorScheme.dark(secondary: Color(0xFF00D1FF)),
        ),
        home: signedIn ? HomeScreen() : SignInScreen(),
      ),
    );
  }
}
