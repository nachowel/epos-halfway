import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/modifier_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/catalog_service.dart';
import '../../domain/services/checkout_service.dart';
import '../../domain/services/order_service.dart';
import '../../domain/services/payment_service.dart';
import '../../domain/services/printer_service.dart';
import '../../domain/services/report_service.dart';
import '../../domain/services/report_visibility_service.dart';
import '../../domain/services/shift_session_service.dart';

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((_) {
  throw UnimplementedError('AppDatabase must be overridden at app bootstrap.');
});

final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>(
      (Ref ref) => UserRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<CategoryRepository> categoryRepositoryProvider =
    Provider<CategoryRepository>(
      (Ref ref) => CategoryRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>(
      (Ref ref) => ProductRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ModifierRepository> modifierRepositoryProvider =
    Provider<ModifierRepository>(
      (Ref ref) => ModifierRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ShiftRepository> shiftRepositoryProvider =
    Provider<ShiftRepository>(
      (Ref ref) => ShiftRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<TransactionRepository> transactionRepositoryProvider =
    Provider<TransactionRepository>(
      (Ref ref) => TransactionRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<PaymentRepository> paymentRepositoryProvider =
    Provider<PaymentRepository>(
      (Ref ref) => PaymentRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<SyncQueueRepository> syncQueueRepositoryProvider =
    Provider<SyncQueueRepository>(
      (Ref ref) => SyncQueueRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ShiftSessionService> shiftSessionServiceProvider =
    Provider<ShiftSessionService>(
      (Ref ref) => ShiftSessionService(ref.watch(shiftRepositoryProvider)),
    );

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => AuthService(
    ref.watch(userRepositoryProvider),
    ref.watch(shiftSessionServiceProvider),
  ),
);

final Provider<CatalogService> catalogServiceProvider =
    Provider<CatalogService>(
      (Ref ref) => CatalogService(
        categoryRepository: ref.watch(categoryRepositoryProvider),
        productRepository: ref.watch(productRepositoryProvider),
        modifierRepository: ref.watch(modifierRepositoryProvider),
      ),
    );

final Provider<OrderService> orderServiceProvider = Provider<OrderService>(
  (Ref ref) => OrderService(
    shiftSessionService: ref.watch(shiftSessionServiceProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
  ),
);

final Provider<PrinterService> printerServiceProvider =
    Provider<PrinterService>(
      (Ref ref) => PrinterService(ref.watch(transactionRepositoryProvider)),
    );

final Provider<PaymentService> paymentServiceProvider =
    Provider<PaymentService>(
      (Ref ref) => PaymentService(
        paymentRepository: ref.watch(paymentRepositoryProvider),
        shiftSessionService: ref.watch(shiftSessionServiceProvider),
        transactionRepository: ref.watch(transactionRepositoryProvider),
        printerService: ref.watch(printerServiceProvider),
      ),
    );

final Provider<CheckoutService> checkoutServiceProvider =
    Provider<CheckoutService>(
      (Ref ref) => CheckoutService(
        database: ref.watch(appDatabaseProvider),
        shiftSessionService: ref.watch(shiftSessionServiceProvider),
        orderService: ref.watch(orderServiceProvider),
        transactionRepository: ref.watch(transactionRepositoryProvider),
        printerService: ref.watch(printerServiceProvider),
      ),
    );

final Provider<ReportService> reportServiceProvider = Provider<ReportService>(
  (Ref ref) => ReportService(
    shiftRepository: ref.watch(shiftRepositoryProvider),
    shiftSessionService: ref.watch(shiftSessionServiceProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    paymentRepository: ref.watch(paymentRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    reportVisibilityService: ref.watch(reportVisibilityServiceProvider),
  ),
);

final Provider<ReportVisibilityService> reportVisibilityServiceProvider =
    Provider<ReportVisibilityService>((_) => const ReportVisibilityService());
