import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'config.dart';
import 'theme.dart';
import 'account_store.dart';
import 'screens/onboarding.dart';
import 'screens/auth.dart';
import 'screens/reset_password.dart';
import 'screens/home.dart';
import 'screens/services.dart';
import 'screens/purchase.dart';
import 'screens/activity.dart';
import 'screens/notifications.dart';
import 'screens/profile.dart';
import 'screens/topup.dart';
import 'screens/beneficiaries.dart';
import 'screens/schedules.dart';
import 'screens/gift.dart';
import 'screens/bulk.dart';
import 'screens/storefront.dart';
import 'screens/security.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    AppConfig.client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  navigatorKey: _rootKey,
  refreshListenable: _AuthRefresh(),
  redirect: (context, state) {
    final loggedIn = AppConfig.client.auth.currentUser != null;
    final location = state.uri.toString();
    final inApp = location.startsWith('/app');
    if (inApp && !loggedIn) return '/auth';
    if (loggedIn && (location == '/' || location == '/auth')) return '/app';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
    GoRoute(path: '/reset-password', builder: (_, _) => const ResetPasswordScreen()),
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        GoRoute(path: '/app', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/app/services', builder: (_, _) => const ServicesScreen()),
        GoRoute(path: '/app/activity', builder: (_, _) => const ActivityScreen()),
        GoRoute(path: '/app/profile', builder: (_, _) => const ProfileScreen()),
      ],
    ),
    // Routes that use root navigator (full screen, no bottom nav)
    GoRoute(
      path: '/app/services/:kind',
      builder: (context, state) => PurchaseScreen(
        kind: state.pathParameters['kind']!,
        initialProviderId: state.uri.queryParameters['provider'],
        initialRecipient: state.uri.queryParameters['recipient'],
        initialProductId: state.uri.queryParameters['product'],
        initialAmountNaira: state.uri.queryParameters['amount'],
      ),
    ),
    GoRoute(path: '/app/notifications', builder: (_, _) => const NotificationsScreen()),
    GoRoute(path: '/app/topup', builder: (_, _) => const TopUpScreen()),
    GoRoute(path: '/app/beneficiaries', builder: (_, _) => const BeneficiariesScreen()),
    GoRoute(path: '/app/schedules', builder: (_, _) => const SchedulesScreen()),
    GoRoute(path: '/app/gift', builder: (_, _) => const GiftScreen()),
    GoRoute(path: '/app/bulk', builder: (_, _) => const BulkDispatchScreen()),
    GoRoute(path: '/app/storefront', builder: (_, _) => const StorefrontScreen()),
    GoRoute(path: '/app/security', builder: (_, _) => const SecurityScreen()),
  ],
);

class AppScaffold extends StatefulWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  static const _paths = ['/app', '/app/services', '/app/activity', '/app/profile'];

  int _indexFor(String location) {
    if (location.startsWith('/app/activity')) return 2;
    if (location.startsWith('/app/profile')) return 3;
    if (location.startsWith('/app/services')) return 1;
    return 0;
  }

  final _titles = const {
    0: ('Good to have you back', 'Home'),
    1: ('Pay in a few taps', 'Services'),
    2: ('Your payment history', 'Activity'),
    3: ('Account and preferences', 'Profile'),
  };

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _indexFor(location);
    final titles = _titles[idx]!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? AppColors.darkCard : AppColors.card;
    final borderColor = dark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles.$1, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
            if (idx != 0) Text(titles.$2, style: displayStyleOf(context, size: 20)),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: accountStore,
            builder: (ctx, child) => IconButton(
              onPressed: () => context.push('/app/notifications'),
              icon: Badge(
                isLabelVisible: accountStore.unread > 0,
                label: Text('${accountStore.unread}'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(999)),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ),
          ),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: dark ? 0.3 : 0.12), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: NavigationBar(
          height: 64,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: idx,
          onDestinationSelected: (i) => context.go(_paths[i]),
          indicatorColor: AppColors.primarySoft,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Services'),
            NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
            NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
