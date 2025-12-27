import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:isd/core/utils/service_locator.dart';
import 'package:isd/features/auth/presentation/view/signin.dart';
import 'package:isd/features/auth/presentation/view_model/login/login_cubit.dart';
import 'package:isd/features/auth/presentation/view_model/signup/signup_cubit.dart';
import 'package:isd/features/home/data/esp_classic_bt_msgpack_source.dart';
import 'package:isd/features/home/data/ingest_ws_client.dart';
import 'package:isd/features/home/data/repos/home_repo_impl.dart';
import 'package:isd/features/home/presentation/view_model/all_trips_cubit/all_trips_cubit.dart';
import 'package:isd/firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isd/features/home/presentation/widgets/telemetry_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  setupServiceLocator();
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
        BlocProvider<AllTripsCubit>(create: (context) => AllTripsCubit(getIt.get<HomeRepoImpl>())),
        BlocProvider<TelemetryCubit>(
  create: (_) => TelemetryCubit(
    source: EspBtClassicSource(debugLog: true),
    ingest: IngestWsClient(
      ingestUri: Uri.parse("ws://3.14.15.242:8000/ws/ingest"),
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
        home: const SignInScreen(),
      ),
    );
  }
}
