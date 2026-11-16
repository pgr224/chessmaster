import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'core/router/app_router.dart';
import 'data/repositories/auth_repository.dart';
import 'core/config/app_config.dart';
import 'core/config/web_push_config.dart';
import 'core/theme/app_theme.dart';
import 'core/di/injection_container.dart' as di;
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/multiplayer/multiplayer_bloc.dart';
import 'presentation/blocs/theme/theme_bloc.dart';
import 'presentation/blocs/settings/settings_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Independent startup work can run together.
  await Future.wait([Hive.initFlutter(), di.init()]);

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

  setNotificationRouteHandler((route) {
    if (di.sl<AuthBloc>().state is! AuthAuthenticatedState) return false;
    AppRouter.router.go(route);
    return true;
  });
  configureWebPush(AppConfig.apiUrl);
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(AuthInitializeEvent()),
        ),
        BlocProvider<MultiplayerBloc>(create: (_) => di.sl<MultiplayerBloc>()),
        BlocProvider<ThemeBloc>(
          lazy: false,
          create: (_) => di.sl<ThemeBloc>()..add(ThemeLoadEvent()),
        ),
        BlocProvider<SettingsBloc>(
          lazy: false,
          create: (_) => di.sl<SettingsBloc>()..add(SettingsLoadEvent()),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            (previous.runtimeType != current.runtimeType ||
                (previous is AuthAuthenticatedState &&
                    current is AuthAuthenticatedState &&
                    previous.user.isGuest != current.user.isGuest)) &&
            current is! AuthLoadingState &&
            current is! AuthInitialState,
        listener: (context, authState) {
          final multiplayerBloc = context.read<MultiplayerBloc>();
          if (authState is AuthAuthenticatedState) {
            context.read<SettingsBloc>().add(
                  SettingsLoadAIDifficultyFromProfile(
                    aiEasyLevel: authState.user.aiEasyLevel,
                    aiMediumLevel: authState.user.aiMediumLevel,
                    aiHardLevel: authState.user.aiHardLevel,
                    aiImpossibleLevel: authState.user.aiImpossibleLevel,
                    aiLastDifficulty: authState.user.aiLastDifficulty,
                  ),
                );
            if (!authState.user.isGuest) {
              context.read<SettingsBloc>().add(SettingsLoadEvent());
              syncWebPush();
              di.sl<AuthRepository>().syncPendingProgress();
              final notificationRoute = takePendingNotificationRoute();
              if (notificationRoute != null)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AppRouter.router.go(notificationRoute);
                });
              multiplayerBloc.add(
                MpConnectLobbyEvent(
                  authState.user.id,
                  authState.user.username,
                  rating: authState.user.stats.eloRating,
                ),
              );
            }
            if (authState.user.isGuest) {
              disableWebPush();
              multiplayerBloc.add(MpDisconnectLobbyEvent());
            }
          } else if (authState is AuthUnauthenticatedState) {
            disableWebPush();
            multiplayerBloc.add(MpDisconnectLobbyEvent());
          }
        },
        child: MaterialApp.router(
          title: 'Chess Master',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}
