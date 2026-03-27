import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/checkout_item.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/checkout_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/payment_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Shift and payment rules', () {
    test(
      'OPEN order payment succeeds when the matching shift is active',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int userId = await insertUser(db, name: 'Admin', role: 'admin');
        final int openShiftId = await insertShift(db, openedBy: userId);
        final int transactionId = await insertTransaction(
          db,
          uuid: 'tx-open-shift',
          shiftId: openShiftId,
          userId: userId,
          status: 'open',
          totalAmountMinor: 850,
        );

        final shiftSessionService = ShiftSessionService(ShiftRepository(db));
        final paymentService = PaymentService(
          paymentRepository: PaymentRepository(db),
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          printerService: PrinterService(TransactionRepository(db)),
        );

        final Payment payment = await paymentService.payOrder(
          transactionId: transactionId,
          method: PaymentMethod.cash,
          currentUser: User(
            id: userId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        final updatedTransaction = await TransactionRepository(
          db,
        ).getById(transactionId);

        expect(payment.amountMinor, 850);
        expect(updatedTransaction, isNotNull);
        expect(updatedTransaction!.status.name, 'paid');
      },
    );

    test(
      'OPEN order payment is rejected when there is no active shift',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int userId = await insertUser(db, name: 'Admin', role: 'admin');
        final int closedShiftId = await insertShift(
          db,
          openedBy: userId,
          status: 'closed',
          closedBy: userId,
          closedAt: DateTime.now(),
        );
        final int transactionId = await insertTransaction(
          db,
          uuid: 'tx-closed-shift',
          shiftId: closedShiftId,
          userId: userId,
          status: 'open',
          totalAmountMinor: 850,
        );

        final paymentService = PaymentService(
          paymentRepository: PaymentRepository(db),
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          printerService: PrinterService(TransactionRepository(db)),
        );

        await expectLater(
          paymentService.payOrder(
            transactionId: transactionId,
            method: PaymentMethod.cash,
            currentUser: User(
              id: userId,
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
      },
    );

    test(
      'checkout still requires an active shift for new order creation',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int userId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int categoryId = await insertCategory(db, name: 'Drinks');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 200,
        );

        final shiftSessionService = ShiftSessionService(ShiftRepository(db));
        final checkoutService = CheckoutService(
          database: db,
          shiftSessionService: shiftSessionService,
          orderService: OrderService(
            shiftSessionService: shiftSessionService,
            transactionRepository: TransactionRepository(db),
          ),
          transactionRepository: TransactionRepository(db),
          printerService: PrinterService(TransactionRepository(db)),
        );

        expect(
          () => checkoutService.checkoutCart(
            currentUser: User(
              id: userId,
              name: 'Cashier',
              pin: null,
              password: null,
              role: UserRole.cashier,
              isActive: true,
              createdAt: DateTime.now(),
            ),
            cartItems: <CheckoutItem>[
              CheckoutItem(
                productId: productId,
                quantity: 1,
                modifiers: const [],
              ),
            ],
            idempotencyKey: 'checkout-no-shift',
          ),
          throwsA(isA<ShiftNotActiveException>()),
        );
      },
    );

    test('PAID and OPEN orders can coexist in the same active shift', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      await insertTransaction(
        db,
        uuid: 'tx-open',
        shiftId: shiftId,
        userId: adminId,
        status: 'open',
        totalAmountMinor: 500,
      );
      await insertTransaction(
        db,
        uuid: 'tx-paid',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 700,
      );

      final transactionRepository = TransactionRepository(db);

      final openOrders = await transactionRepository.getByShiftAndStatus(
        shiftId,
        TransactionStatus.open,
      );
      final paidOrders = await transactionRepository.getByShiftAndStatus(
        shiftId,
        TransactionStatus.paid,
      );

      expect(openOrders, hasLength(1));
      expect(paidOrders, hasLength(1));
    });
  });
}
