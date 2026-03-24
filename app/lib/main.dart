import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/di/injection_container.dart' as di;
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/theme/theme_bloc.dart';
import 'presentation/blocs/settings/settings_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive local storage
  await Hive.initFlutter();

  // Initialize dependency injection
  await di.init();

  // Lock orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Immersive UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E27),
    ),
  );

  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()..add(AuthInitializeEvent())),
        BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()..add(ThemeLoadEvent())),
        BlocProvider<SettingsBloc>(create: (_) => di.sl<SettingsBloc>()..add(SettingsLoadEvent())),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'Chess Master',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
