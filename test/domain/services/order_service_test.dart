import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('OrderService', () {
    test('open order summary uses order no, time flow, and short content', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Breakfast');
      final int teaId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Tea',
        priceMinor: 200,
      );
      final int breakfastId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Breakfast',
        priceMinor: 700,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
      );

      final transactionRepository = TransactionRepository(db);
      final int orderId = await insertTransaction(
        db,
        uuid: 'open-order-summary',
        shiftId: shiftId,
        userId: cashierId,
        status: 'open',
        totalAmountMinor: 1100,
      );
      await transactionRepository.addLine(
        transactionId: orderId,
        productId: teaId,
        quantity: 2,
      );
      await transactionRepository.addLine(
        transactionId: orderId,
        productId: breakfastId,
        quantity: 1,
      );

      final summaries = await service.getOpenOrderSummaries();

      expect(summaries, hasLength(1));
      expect(summaries.single.transaction.id, orderId);
      expect(summaries.single.itemCount, 3);
      expect(summaries.single.shortContent, '2 Tea, 1 Breakfast');
    });

    test('table number is nullable and can be updated later', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'table-number-order',
        shiftId: shiftId,
        userId: cashierId,
        status: 'open',
        totalAmountMinor: 600,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
      );

      await service.updateTableNumber(transactionId: transactionId, tableNumber: 12);
      final withTable = await service.getOrderById(transactionId);

      await service.updateTableNumber(transactionId: transactionId, tableNumber: null);
      final withoutTable = await service.getOrderById(transactionId);

      expect(withTable, isNotNull);
      expect(withTable!.tableNumber, 12);
      expect(withoutTable, isNotNull);
      expect(withoutTable!.tableNumber, isNull);
    });

    test('cashier can cancel only their own open orders', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int firstCashierId = await insertUser(
        db,
        name: 'Cashier One',
        role: 'cashier',
      );
      final int secondCashierId = await insertUser(
        db,
        name: 'Cashier Two',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: firstCashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'cashier-cancel',
        shiftId: shiftId,
        userId: firstCashierId,
        status: 'open',
        totalAmountMinor: 600,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
      );

      await expectLater(
        service.cancelOrder(
          transactionId: transactionId,
          currentUser: User(
            id: secondCashierId,
            name: 'Cashier Two',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<UnauthorisedException>()),
      );
    });
  });
}
