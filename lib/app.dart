import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/purchase_evaluation.dart';
import 'providers/notification_provider.dart';
import 'screens/history/history_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/results/history_result_screen.dart';
import 'screens/results/results_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class PauseApp extends ConsumerStatefulWidget {
  final bool hasProfile;
  final PurchaseEvaluation? initialEvaluation;

  const PauseApp({super.key, required this.hasProfile, this.initialEvaluation});

  @override
  ConsumerState<PauseApp> createState() => _PauseAppState();
}

class _PauseAppState extends ConsumerState<PauseApp> {
  late final GoRouter _router;
  StreamSubscription<PurchaseEvaluation>? _sub;
  String? _coldStartId;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: widget.hasProfile ? '/' : '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => _ShellScaffold(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/results',
          builder: (context, state) =>
              ResultsScreen(evaluation: state.extra as PurchaseEvaluation),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/history/result',
          builder: (context, state) => HistoryResultScreen(
            evaluation: state.extra as PurchaseEvaluation,
          ),
        ),
      ],
    );

    // Cold-start deep link.
    if (widget.initialEvaluation != null) {
      _coldStartId = widget.initialEvaluation!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _router.push('/results', extra: widget.initialEvaluation);
      });
    }

    // Foreground taps.
    _sub = ref.read(notificationServiceProvider).onSelect.listen((evaluation) {
      if (evaluation.id == _coldStartId) {
        _coldStartId = null;
        return;
      }
      _router.push('/results', extra: evaluation);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pause',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  final Widget child;

  const _ShellScaffold({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex(context),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/history');
            case 2:
              context.go('/settings');
          }
        },
      ),
    );
  }
}
