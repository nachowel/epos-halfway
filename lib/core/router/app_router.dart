import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/user.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/auth/pin_screen.dart';
import '../../presentation/screens/orders/open_orders_screen.dart';
import '../../presentation/screens/pos/pos_screen.dart';
import '../../presentation/screens/reports/z_report_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/shifts/shift_management_screen.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (_, __) => '/login'),
      GoRoute(path: '/login', builder: (_, __) => const PinScreen()),
      GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OpenOrdersScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ZReportScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/shifts',
        builder: (_, __) => const ShiftManagementScreen(),
      ),
    ],
    redirect: (_, GoRouterState state) {
      final User? currentUser = authState.currentUser;
      final bool isLoggedIn = currentUser != null;
      final bool isLoginRoute = state.matchedLocation == '/login';
      final bool isShiftRoute = state.matchedLocation == '/shifts';
      final bool isSettingsRoute = state.matchedLocation == '/settings';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }
      if (isLoggedIn && isLoginRoute) {
        return '/pos';
      }
      if (isShiftRoute && currentUser?.role != UserRole.admin) {
        return '/pos';
      }
      if (isSettingsRoute && currentUser?.role != UserRole.admin) {
        return '/pos';
      }
      return null;
    },
  );
});
