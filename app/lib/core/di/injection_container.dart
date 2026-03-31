import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../router/app_router.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/puzzle_repository.dart';
import '../../data/services/multiplayer_service.dart';
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/game/game_bloc.dart';
import '../../presentation/blocs/multiplayer/multiplayer_bloc.dart';
import '../../presentation/blocs/theme/theme_bloc.dart';
import '../../presentation/blocs/settings/settings_bloc.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/mission_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ── SharedPreferences ──
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  sl.registerSingleton<AchievementService>(AchievementService(sl<SharedPreferences>()));

  // ── External services ──
  sl.registerLazySingleton<Dio>(() {
    var isRecoveringFrom401 = false;

    final dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_URL'] ??
          'https://chess-master-api.pp942920.workers.dev',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Interceptor to inject auth token
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = sl<SharedPreferences>().getString('auth_token');
        if (token != null) {
          final normalized = token
              .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
              .trim();
          options.headers['Authorization'] = 'Bearer $normalized';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final hasAuthHeader =
              e.requestOptions.headers.containsKey('Authorization');
          if (hasAuthHeader && !isRecoveringFrom401) {
            isRecoveringFrom401 = true;
            try {
              // Manual cleanup to avoid dependencies
              await sl<SharedPreferences>().remove('auth_token');
              await sl<SharedPreferences>().remove('user_data');
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
  sl.registerLazySingleton<PuzzleRepository>(() => PuzzleRepository());
  sl.registerSingleton<MultiplayerService>(MultiplayerService());
  sl.registerSingleton<MissionService>(MissionService(sl<SharedPreferences>(), sl<AuthRepository>()));

  // ── BLoCs ──
  sl.registerLazySingleton<AuthBloc>(() => AuthBloc(sl<AuthRepository>()));
        sl.registerFactory<GameBloc>(() => GameBloc(
        sl<GameRepository>(),
        sl<AuthRepository>(),
        sl<PuzzleRepository>(),
        sl<ThemeBloc>(),
        sl<AchievementService>(),
        sl<MissionService>(),
      ));
  sl.registerLazySingleton<MultiplayerBloc>(
      () => MultiplayerBloc(sl<MultiplayerService>()));
  sl.registerLazySingleton<ThemeBloc>(() => ThemeBloc());
  sl.registerLazySingleton<SettingsBloc>(() => SettingsBloc());
}
