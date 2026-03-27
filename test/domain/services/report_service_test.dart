import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('ReportService', () {
    test('cashier can take masked Z report without closing the real shift', () async {
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
        status: 'open',
        totalAmountMinor: 1000,
      );
      final int openTransactionId = await insertTransaction(
        db,
        uuid: 'open-report-tx',
        shiftId: shiftId,
        userId: cashierId,
        status: 'open',
        totalAmountMinor: 400,
      );

      final PaymentRepository paymentRepository = PaymentRepository(db);
      await paymentRepository.createPayment(
        transactionId: paidTransactionId,
        uuid: 'payment-for-report',
        method: PaymentMethod.cash,
        amountMinor: 1000,
      );

      final ShiftRepository shiftRepository = ShiftRepository(db);
      final TransactionRepository transactionRepository = TransactionRepository(
        db,
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

      await SettingsRepository(db).updateVisibilityRatio(
        0.25,
        userId: adminId,
      );

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

      final adminSnapshot = await shiftSessionService.getSnapshotForUser(admin);
      expect(adminSnapshot.backendOpenShift, isNotNull);
      expect(adminSnapshot.visibleShift, isNotNull);
      expect(adminSnapshot.salesLocked, isFalse);
    });

    test('admin final Z report closes the real shift with real totals', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int paidTransactionId = await insertTransaction(
        db,
        uuid: 'paid-final-close',
        shiftId: shiftId,
        userId: adminId,
        status: 'open',
        totalAmountMinor: 1600,
      );

      final PaymentRepository paymentRepository = PaymentRepository(db);
      await paymentRepository.createPayment(
        transactionId: paidTransactionId,
        uuid: 'payment-final-close',
        method: PaymentMethod.card,
        amountMinor: 1600,
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

      final result = await reportService.runAdminFinalClose(
        user: User(
          id: adminId,
          name: 'Admin',
          pin: null,
          password: null,
          role: UserRole.admin,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      final openShiftAfterClose = await shiftRepository.getOpenShift();

      expect(result.finalCloseCompleted, isTrue);
      expect(result.report.paidTotalMinor, 1600);
      expect(openShiftAfterClose, isNull);
    });

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
        status: 'open',
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
        reportService.runAdminFinalClose(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<OpenOrdersExistException>()),
      );
    });
  });
}
