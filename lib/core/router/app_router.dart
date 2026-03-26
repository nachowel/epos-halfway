import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/auth/pin_screen.dart';
import '../../presentation/screens/orders/open_orders_screen.dart';
import '../../presentation/screens/pos/pos_screen.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (_, __) => '/login'),
      GoRoute(path: '/login', builder: (_, __) => const PinScreen()),
      GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OpenOrdersScreen()),
    ],
    redirect: (_, GoRouterState state) {
      final bool isLoggedIn = authState.currentUser != null;
      final bool isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }
      if (isLoggedIn && isLoginRoute) {
        return '/pos';
      }
      return null;
    },
  );
});
