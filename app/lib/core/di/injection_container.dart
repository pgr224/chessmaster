import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../router/app_router.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/services/multiplayer_service.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/game/game_bloc.dart';
import '../../presentation/blocs/multiplayer/multiplayer_bloc.dart';
import '../../presentation/blocs/theme/theme_bloc.dart';
import '../../presentation/blocs/settings/settings_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ── External services ──
  sl.registerLazySingleton<Dio>(() {
    var isRecoveringFrom401 = false;

    final dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_URL'] ?? 'https://chess-api.yourdomain.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor to inject auth token
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await sl<AuthRepository>().getToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final hasAuthHeader = e.requestOptions.headers.containsKey('Authorization');
          if (hasAuthHeader && !isRecoveringFrom401) {
            isRecoveringFrom401 = true;
            try {
              await sl<AuthRepository>().signOut();
              if (AppRouter.router.state.matchedLocation != '/onboarding') {
                AppRouter.router.go('/onboarding?reason=session_expired');
              }
            } finally {
              isRecoveringFrom401 = false;
            }
          }
        }
        handler.next(e);
      },
    ));
    return dio;
  });

  // ── Repositories ──
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository(sl<Dio>()));
  sl.registerLazySingleton<GameRepository>(() => GameRepository(sl<Dio>()));
  sl.registerSingleton<MultiplayerService>(MultiplayerService());

  // ── BLoCs ──
  sl.registerLazySingleton<AuthBloc>(() => AuthBloc(sl<AuthRepository>()));
  sl.registerFactory<GameBloc>(() => GameBloc(sl<GameRepository>()));
  sl.registerLazySingleton<MultiplayerBloc>(() => MultiplayerBloc(sl<MultiplayerService>()));
  sl.registerLazySingleton<ThemeBloc>(() => ThemeBloc());
  sl.registerLazySingleton<SettingsBloc>(() => SettingsBloc());
}
