import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../di/injection_container.dart' as di;
import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/blocs/game/game_bloc.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/game/game_screen.dart';
import '../../presentation/screens/game/game_setup_screen.dart';
import '../../presentation/screens/multiplayer/lobby_screen.dart';
import '../../presentation/screens/multiplayer/matchmaking_screen.dart';
import '../../presentation/screens/multiplayer/game_room_screen.dart';
import '../../presentation/screens/news/chess_world_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/leaderboard/leaderboard_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/donation_settings_screen.dart';
import '../../presentation/screens/tutorial/tutorial_screen.dart';
import '../../presentation/screens/learn/learn_screen.dart';
import '../../presentation/screens/learn/article_screen.dart';
import '../../presentation/screens/learn/week_screen.dart';
import '../../presentation/screens/achievements/achievements_screen.dart';
import '../../presentation/screens/tournament/tournament_invite_screen.dart';
import '../../presentation/screens/tournament/tournament_lobby_screen.dart';
import '../../presentation/screens/tournament/tournament_result_screen.dart';
import '../../presentation/blocs/tournament/tournament_bloc.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../data/models/game_config.dart';
import '../../data/models/tutorial_model.dart';
export '../../data/models/game_config.dart';

class GameRouteExtra {
  final GameConfig config;
  final TutorialLesson? tutorial;

  const GameRouteExtra({
    required this.config,
    this.tutorial,
  });
}

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final authBloc = di.sl<AuthBloc>();
      final isAuthenticated = authBloc.state is AuthAuthenticatedState;
      final isSplash = state.matchedLocation == '/splash';
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (isSplash || isOnboarding) return null;
      if (!isAuthenticated) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/learn',
            name: 'learn',
            builder: (context, state) => const LearnScreen(),
            routes: [
              GoRoute(
                path: 'article/:id',
                name: 'article',
                builder: (context, state) => ArticleScreen(
                  articleId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'week/:number',
                name: 'week_detail',
                builder: (context, state) => WeekScreen(
                  weekNumber: int.parse(state.pathParameters['number']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/leaderboard',
            name: 'leaderboard',
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/donations',
            name: 'settings_donations',
            builder: (context, state) => const DonationSettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/game/setup',
        name: 'game_setup',
        builder: (context, state) => const GameSetupScreen(),
      ),
      GoRoute(
        path: '/game/play',
        name: 'game_play',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is GameRouteExtra) {
            return BlocProvider<GameBloc>(
              create: (_) => di.sl<GameBloc>(),
              child: GameScreen(config: extra.config, tutorial: extra.tutorial),
            );
          }
          final config = extra is GameConfig
              ? extra
              : const GameConfig(
                  mode: GameMode.singlePlayer,
                  playerColor: 'white',
                  difficulty: AIDifficulty.basic);

          return BlocProvider<GameBloc>(
            create: (_) => di.sl<GameBloc>(),
            child: GameScreen(config: config),
          );
        },
      ),
      GoRoute(
        path: '/tutorial',
        name: 'tutorial',
        builder: (context, state) => const TutorialScreen(),
      ),
      GoRoute(
        path: '/lobby',
        name: 'lobby',
        builder: (context, state) => LobbyScreen(
          initialChallengeId: state.uri.queryParameters['accept_challenge'],
          autoAccept: state.uri.queryParameters['auto_accept'] == 'true',
          initialXpRequestId: state.uri.queryParameters['xp_request_id'],
          autoAcceptXp: state.uri.queryParameters['auto_accept_xp'] == 'true',
          autoRejectXp: state.uri.queryParameters['auto_reject_xp'] == 'true',
        ),
      ),
      GoRoute(
        path: '/matchmaking',
        name: 'matchmaking',
        builder: (context, state) => const MatchmakingScreen(),
      ),
      GoRoute(
        path: '/room/:gameId',
        name: 'game_room',
        builder: (context, state) => BlocProvider<GameBloc>(
          create: (_) => di.sl<GameBloc>(),
          child: GameRoomScreen(
            gameId: state.pathParameters['gameId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/chess_world',
        name: 'chess_world',
        builder: (context, state) => const ChessWorldScreen(),
      ),
      GoRoute(
        path: '/achievements',
        name: 'achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/tournament/invite',
        name: 'tournament_invite',
        builder: (context, state) => const TournamentInviteScreen(),
      ),
      GoRoute(
        path: '/tournament/:id',
        name: 'tournament_lobby',
        builder: (context, state) => BlocProvider<TournamentBloc>(
          create: (_) => TournamentBloc(
            di.sl<TournamentRepository>(),
            di.sl(),
          ),
          child: TournamentLobbyScreen(
            tournamentId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/tournament/:id/result',
        name: 'tournament_result',
        builder: (context, state) => BlocProvider<TournamentBloc>(
          create: (_) => TournamentBloc(
            di.sl<TournamentRepository>(),
            di.sl(),
          ),
          child: TournamentResultScreen(
            tournamentId: state.pathParameters['id']!,
          ),
        ),
      ),
    ],
  );
}

class MainScaffold extends StatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int get _currentIndex {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/learn')) return 1;
    if (location.startsWith('/leaderboard')) return 2;
    if (location.startsWith('/profile')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Home', path: '/home'),
    _NavItem(icon: Icons.school_rounded, label: 'Learn', path: '/learn'),
    _NavItem(
        icon: Icons.leaderboard_rounded, label: 'Ranks', path: '/leaderboard'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile', path: '/profile'),
    _NavItem(
        icon: Icons.settings_rounded, label: 'Settings', path: '/settings'),
  ];

  DateTime? _lastBackPressed;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If not at home, go home first
        if (_currentIndex != 0) {
          context.go('/home');
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Press back again to exit',
                  style: GoogleFonts.fredoka()),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF1F2952),
            ),
          );
          return;
        }

        // Double back pressed within 2s -> show dialogue
        final shouldExit = await _showExitDialogue(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Future<bool?> _showExitDialogue(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0E27),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        ),
        title: Text('Quit Game?',
            style: GoogleFonts.fredoka(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to exit Chess Master?',
            style: GoogleFonts.baloo2(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.fredoka(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Quit',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1535), Color(0xFF0A0E27)],
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF1F2952), width: 1),
        ),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          context.go(_navItems[index].path);
        },
        indicatorColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
        destinations: [
          for (final item in _navItems)
            NavigationDestination(
              icon: Icon(item.icon, color: const Color(0xFF4A5580)),
              selectedIcon: Icon(item.icon, color: const Color(0xFFD4AF37)),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem({required this.icon, required this.label, required this.path});
}

