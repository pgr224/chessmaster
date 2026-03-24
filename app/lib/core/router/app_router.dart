import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/blocs/auth/auth_bloc.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/game/game_screen.dart';
import '../../presentation/screens/game/game_setup_screen.dart';
import '../../presentation/screens/multiplayer/lobby_screen.dart';
import '../../presentation/screens/multiplayer/matchmaking_screen.dart';
import '../../presentation/screens/multiplayer/game_room_screen.dart';
import '../../presentation/screens/tournament/tournament_screen.dart';
import '../../presentation/screens/tournament/bracket_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/leaderboard/leaderboard_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/tutorial/tutorial_screen.dart';
import '../../presentation/screens/learn/learn_screen.dart';
import '../../presentation/screens/learn/article_screen.dart';
import '../../data/models/user_model.dart';
import '../../data/models/game_config.dart';
export '../../data/models/game_config.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final authState = context.read<AuthBloc>().state;
      final isAuthenticated = authState is AuthAuthenticatedState;
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
        builder: (context, state) => GameScreen(
          config: state.extra as GameConfig,
        ),
      ),
      GoRoute(
        path: '/tutorial',
        name: 'tutorial',
        builder: (context, state) => const TutorialScreen(),
      ),
      GoRoute(
        path: '/lobby',
        name: 'lobby',
        builder: (context, state) => const LobbyScreen(),
      ),
      GoRoute(
        path: '/matchmaking',
        name: 'matchmaking',
        builder: (context, state) => const MatchmakingScreen(),
      ),
      GoRoute(
        path: '/room/:gameId',
        name: 'game_room',
        builder: (context, state) => GameRoomScreen(
          gameId: state.pathParameters['gameId']!,
        ),
      ),
      GoRoute(
        path: '/tournaments',
        name: 'tournaments',
        builder: (context, state) => const TournamentScreen(),
      ),
      GoRoute(
        path: '/tournament/:id/bracket',
        name: 'bracket',
        builder: (context, state) => BracketScreen(
          tournamentId: state.pathParameters['id']!,
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
  int _currentIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Home', path: '/home'),
    _NavItem(icon: Icons.school_rounded, label: 'Learn', path: '/learn'),
    _NavItem(icon: Icons.leaderboard_rounded, label: 'Ranks', path: '/leaderboard'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile', path: '/profile'),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF0F1535), const Color(0xFF0A0E27)],
        ),
        border: const Border(
          top: BorderSide(color: Color(0xFF1F2952), width: 1),
        ),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          context.go(_navItems[index].path);
        },
        indicatorColor: const Color(0xFFD4AF37).withOpacity(0.2),
        destinations: _navItems.map((item) => NavigationDestination(
          icon: Icon(item.icon, color: const Color(0xFF4A5580)),
          selectedIcon: Icon(item.icon, color: const Color(0xFFD4AF37)),
          label: item.label,
        )).toList(),
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
