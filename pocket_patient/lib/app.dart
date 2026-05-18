import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'config/constants.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/placeholder_screen.dart';
import 'services/auth_service.dart';

final _authService = AuthService();

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final hasToken = await _authService.hasToken();
    if (!hasToken && state.matchedLocation != '/login') return '/login';
    if (hasToken && state.matchedLocation == '/login') return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/placeholder', builder: (_, __) => const PlaceholderScreen()),
  ],
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: kAppName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFCC0033)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
