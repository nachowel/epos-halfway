import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/shift_close_readiness.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('ReportService', () {
    test(
      'cashier can take masked Z report without closing the real shift',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: cashierId);
        final int paidTransactionId = await insertTransaction(
          db,
          uuid: 'paid-report-tx',
          shiftId: shiftId,
          userId: cashierId,
          status: 'draft',
          totalAmountMinor: 1000,
        );
        final int openTransactionId = await insertTransaction(
          db,
          uuid: 'open-report-tx',
          shiftId: shiftId,
          userId: cashierId,
          status: 'sent',
          totalAmountMinor: 400,
        );

        final PaymentRepository paymentRepository = PaymentRepository(db);
        final int categoryId = await insertCategory(db, name: 'Report Items');
        final int paidProductId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Meal',
          priceMinor: 1000,
        );
        await TransactionRepository(db).addLine(
          transactionId: paidTransactionId,
          productId: paidProductId,
          quantity: 1,
        );

        final ShiftRepository shiftRepository = ShiftRepository(db);
        final TransactionRepository transactionRepository =
            TransactionRepository(db);
        final OrderService orderService = OrderService(
          shiftSessionService: ShiftSessionService(shiftRepository),
          transactionRepository: transactionRepository,
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: paymentRepository,
        );
        await orderService.sendOrder(
          transactionId: paidTransactionId,
          currentUser: User(
            id: cashierId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        await orderService.markOrderPaid(
          transactionId: paidTransactionId,
          method: PaymentMethod.cash,
          currentUser: User(
            id: cashierId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        final ShiftSessionService shiftSessionService = ShiftSessionService(
          shiftRepository,
        );
        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: shiftSessionService,
          transactionRepository: transactionRepository,
          paymentRepository: paymentRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        await SettingsRepository(
          db,
        ).updateVisibilityRatio(0.25, userId: adminId);

        final cashier = User(
          id: cashierId,
          name: 'Cashier',
          pin: null,
          password: null,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime.now(),
        );
        final admin = User(
          id: adminId,
          name: 'Admin',
          pin: null,
          password: null,
          role: UserRole.admin,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final maskedPreview = await reportService.takeCashierEndOfDayPreview(
          user: cashier,
        );
        final maskedPrintedReport = await reportService.getVisibleShiftReport(
          shiftId: shiftId,
          user: cashier,
        );
        final realPrintedReport = await reportService.getVisibleShiftReport(
          shiftId: shiftId,
          user: admin,
        );
        final openShiftAfterPreview = await shiftRepository.getOpenShift();
        final openTransaction = await transactionRepository.getById(
          openTransactionId,
        );

        expect(maskedPreview.finalCloseCompleted, isFalse);
        expect(maskedPreview.report.paidTotalMinor, 250);
        expect(maskedPreview.report.openTotalMinor, 100);
        expect(maskedPrintedReport, maskedPreview.report);
        expect(realPrintedReport.paidTotalMinor, 1000);
        expect(realPrintedReport.openTotalMinor, 400);
        expect(openShiftAfterPreview, isNotNull);
        expect(openShiftAfterPreview!.id, shiftId);
        expect(openShiftAfterPreview.hasCashierPreview, isTrue);

        await expectLater(
          shiftSessionService.ensureOrderCreationAllowed(cashier),
          throwsA(isA<CashierPreviewLockedException>()),
        );
        await expectLater(
          shiftSessionService.ensurePaymentAllowed(
            user: cashier,
            transaction: openTransaction!,
          ),
          throwsA(isA<CashierPreviewLockedException>()),
        );

        final adminSnapshot = await shiftSessionService.getSnapshotForUser(
          admin,
        );
        expect(adminSnapshot.backendOpenShift, isNotNull);
        expect(adminSnapshot.visibleShift, isNotNull);
        expect(adminSnapshot.salesLocked, isFalse);
      },
    );

    test(
      'admin final Z report closes the real shift with real totals',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidTransactionId = await insertTransaction(
          db,
          uuid: 'paid-final-close',
          shiftId: shiftId,
          userId: adminId,
          status: 'draft',
          totalAmountMinor: 1600,
        );

        final PaymentRepository paymentRepository = PaymentRepository(db);
        final int categoryId = await insertCategory(db, name: 'Final Close');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Roast',
          priceMinor: 1600,
        );
        await TransactionRepository(db).addLine(
          transactionId: paidTransactionId,
          productId: productId,
          quantity: 1,
        );
        final OrderService orderService = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: paymentRepository,
        );
        await orderService.sendOrder(
          transactionId: paidTransactionId,
          currentUser: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        await orderService.markOrderPaid(
          transactionId: paidTransactionId,
          method: PaymentMethod.card,
          currentUser: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );

        final ShiftRepository shiftRepository = ShiftRepository(db);
        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: ShiftSessionService(shiftRepository),
          transactionRepository: TransactionRepository(db),
          paymentRepository: paymentRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        final result = await reportService.runAdminFinalCloseWithCountedCash(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          countedCashMinor: 0,
        );

        final openShiftAfterClose = await shiftRepository.getOpenShift();

        expect(result.finalCloseCompleted, isTrue);
        expect(result.report.paidTotalMinor, 1600);
        expect(openShiftAfterClose, isNull);
      },
    );

    test('final close is rejected while open orders still exist', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      await insertTransaction(
        db,
        uuid: 'still-open-before-close',
        shiftId: shiftId,
        userId: adminId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      final ShiftRepository shiftRepository = ShiftRepository(db);
      final ReportService reportService = ReportService(
        shiftRepository: shiftRepository,
        shiftSessionService: ShiftSessionService(shiftRepository),
        transactionRepository: TransactionRepository(db),
        paymentRepository: PaymentRepository(db),
        settingsRepository: SettingsRepository(db),
        reportVisibilityService: const ReportVisibilityService(),
      );

      await expectLater(
        reportService.runAdminFinalCloseWithCountedCash(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          countedCashMinor: 0,
        ),
        throwsA(
          isA<ShiftCloseBlockedException>().having(
            (ShiftCloseBlockedException error) =>
                error.readiness.blockingReason,
            'blockingReason',
            ShiftCloseBlockReason.sentOrdersPending,
          ).having(
            (ShiftCloseBlockedException error) => error.suggestedAction,
            'suggestedAction',
            ShiftCloseSuggestedAction.completeOrCancelActiveOrders,
          ),
        ),
      );
    });

    test(
      'final close leaves sales and payments blocked until next login opens shift',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int transactionId = await insertTransaction(
          db,
          uuid: 'final-close-blocks',
          shiftId: shiftId,
          userId: adminId,
          status: 'draft',
          totalAmountMinor: 900,
        );

        final paymentRepository = PaymentRepository(db);
        final int categoryId = await insertCategory(db, name: 'Close Lock');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Coffee Pot',
          priceMinor: 900,
        );
        await TransactionRepository(db).addLine(
          transactionId: transactionId,
          productId: productId,
          quantity: 1,
        );
        final OrderService orderService = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: paymentRepository,
        );
        await orderService.sendOrder(
          transactionId: transactionId,
          currentUser: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        await orderService.markOrderPaid(
          transactionId: transactionId,
          method: PaymentMethod.cash,
          currentUser: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );

        final shiftRepository = ShiftRepository(db);
        final shiftSessionService = ShiftSessionService(shiftRepository);
        final reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          paymentRepository: paymentRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        await reportService.runAdminFinalCloseWithCountedCash(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          countedCashMinor: 900,
        );

        final closedTransaction = await TransactionRepository(
          db,
        ).getById(transactionId);

        await expectLater(
          shiftSessionService.ensureOrderCreationAllowed(
            User(
              id: adminId,
              name: 'Admin',
              pin: null,
              password: null,
              role: UserRole.admin,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          ),
          throwsA(isA<ShiftNotActiveException>()),
        );
        await expectLater(
          shiftSessionService.ensurePaymentAllowed(
            user: User(
              id: adminId,
              name: 'Admin',
              pin: null,
              password: null,
              role: UserRole.admin,
              isActive: true,
              createdAt: DateTime.now(),
            ),
            transaction: closedTransaction!,
          ),
          throwsA(isA<ShiftNotActiveException>()),
        );
      },
    );
  });
}
