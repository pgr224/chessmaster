import 'dart:async';
import 'package:chess_master/presentation/widgets/guest_account_prompt.dart';
import 'package:chess_master/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:chess_master/presentation/blocs/auth/auth_bloc.dart';
import 'package:chess_master/data/repositories/auth_repository.dart';
import 'package:chess_master/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Auth extends Mock implements AuthBloc {}

class _Repository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'guest online access screen offers account creation, login and offline play on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/guest-access', routes: [
      GoRoute(
          path: '/guest-access',
          builder: (_, s) =>
              const GuestAccessScreen(feature: 'Online multiplayer')),
      GoRoute(
          path: '/onboarding',
          builder: (_, s) => Text(
              'account=${s.uri.queryParameters['account']} login=${s.uri.queryParameters['login']}')),
      GoRoute(path: '/home', builder: (_, s) => const Text('Offline home')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Keep playing offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('account=true login=true'), findsOneWidget);
  });
  testWidgets('post-game prompt explains temporary XP and opens registration',
      (tester) async {
    final router = GoRouter(initialLocation: '/result', routes: [
      GoRoute(
          path: '/result',
          builder: (_, s) => const Scaffold(body: GuestAccountPrompt())),
      GoRoute(
          path: '/onboarding',
          builder: (_, s) =>
              Text('account=${s.uri.queryParameters['account']}')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.textContaining('Guest XP is temporary'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('account=true'), findsOneWidget);
  });
  testWidgets(
      'resetting guest XP while opening the account form does not bounce back home',
      (tester) async {
    final auth = _Auth(), repository = _Repository();
    final stream = StreamController<AuthState>.broadcast();
    addTearDown(stream.close);
    const guest = UserModel(
        id: 'guest_one',
        username: 'Guest',
        xp: 0,
        isOnline: false,
        deviceId: 'same-device',
        stats: UserStats(),
        isGuest: true);
    when(() => auth.state).thenReturn(const AuthAuthenticatedState(guest));
    when(() => auth.stream).thenAnswer((_) => stream.stream);
    when(() => auth.authRepository).thenReturn(repository);
    when(() => repository.getLastLoggedOutUsername())
        .thenAnswer((_) async => null);
    final router = GoRouter(initialLocation: '/onboarding', routes: [
      GoRoute(
          path: '/onboarding',
          builder: (_, s) => const OnboardingScreen(showAccountForm: true)),
      GoRoute(path: '/home', builder: (_, s) => const Text('Offline home')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
        value: auth, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    stream.add(AuthAuthenticatedState(guest.copyWith(id: 'guest_reset')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/onboarding');
    expect(find.text('Log in on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
