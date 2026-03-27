import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;

class SyncPayloadRepository {
  const SyncPayloadRepository(this._database);

  final db.AppDatabase _database;

  Future<String?> resolveTransactionUuid({
    required String tableName,
    required String recordUuid,
  }) async {
    switch (tableName) {
      case 'transactions':
        final db.Transaction? transaction =
            await (_database.select(_database.transactions)..where(
                  (db.$TransactionsTable t) => t.uuid.equals(recordUuid),
                ))
                .getSingleOrNull();
        return transaction?.uuid;
      case 'transaction_lines':
        final db.TransactionLine? line =
            await (_database.select(_database.transactionLines)..where(
                  (db.$TransactionLinesTable t) => t.uuid.equals(recordUuid),
                ))
                .getSingleOrNull();
        if (line == null) {
          return null;
        }
        final db.Transaction? transaction =
            await (_database.select(_database.transactions)..where(
                  (db.$TransactionsTable t) => t.id.equals(line.transactionId),
                ))
                .getSingleOrNull();
        return transaction?.uuid;
      case 'order_modifiers':
        final db.OrderModifier? modifier =
            await (_database.select(_database.orderModifiers)..where(
                  (db.$OrderModifiersTable t) => t.uuid.equals(recordUuid),
                ))
                .getSingleOrNull();
        if (modifier == null) {
          return null;
        }
        final db.TransactionLine? line =
            await (_database.select(_database.transactionLines)..where(
                  (db.$TransactionLinesTable t) =>
                      t.id.equals(modifier.transactionLineId),
                ))
                .getSingleOrNull();
        if (line == null) {
          return null;
        }
        final db.Transaction? transaction =
            await (_database.select(_database.transactions)..where(
                  (db.$TransactionsTable t) => t.id.equals(line.transactionId),
                ))
                .getSingleOrNull();
        return transaction?.uuid;
      case 'payments':
        final db.Payment? payment =
            await (_database.select(_database.payments)
                  ..where((db.$PaymentsTable t) => t.uuid.equals(recordUuid)))
                .getSingleOrNull();
        if (payment == null) {
          return null;
        }
        final db.Transaction? transaction =
            await (_database.select(_database.transactions)..where(
                  (db.$TransactionsTable t) =>
                      t.id.equals(payment.transactionId),
                ))
                .getSingleOrNull();
        return transaction?.uuid;
      default:
        throw ArgumentError.value(
          tableName,
          'tableName',
          'Unsupported sync table',
        );
    }
  }

  Future<SyncTransactionGraph?> buildTransactionGraph(
    String transactionUuid,
  ) async {
    final db.Transaction? transaction =
        await (_database.select(_database.transactions)..where(
              (db.$TransactionsTable t) => t.uuid.equals(transactionUuid),
            ))
            .getSingleOrNull();
    if (transaction == null) {
      return null;
    }
    if (transaction.status == 'draft' || transaction.status == 'sent') {
      throw StateError('Only terminal transactions may be synced.');
    }

    final Map<String, Object?> transactionPayload =
        await _buildTransactionPayload(transactionUuid) ??
        (throw StateError('Transaction payload missing for $transactionUuid.'));

    final List<db.TransactionLine> lineRows =
        await (_database.select(_database.transactionLines)
              ..where(
                (db.$TransactionLinesTable t) =>
                    t.transactionId.equals(transaction.id),
              )
              ..orderBy(<OrderingTerm Function(db.$TransactionLinesTable)>[
                (db.$TransactionLinesTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final List<SyncGraphRecord> records = <SyncGraphRecord>[
      SyncGraphRecord(
        tableName: 'transactions',
        recordUuid: transaction.uuid,
        payload: transactionPayload,
        idempotencyKey: transaction.idempotencyKey,
      ),
    ];

    for (final db.TransactionLine line in lineRows) {
      final Map<String, Object?> linePayload =
          await _buildTransactionLinePayload(line.uuid) ??
          (throw StateError(
            'Transaction line payload missing for ${line.uuid}.',
          ));
      records.add(
        SyncGraphRecord(
          tableName: 'transaction_lines',
          recordUuid: line.uuid,
          payload: linePayload,
          idempotencyKey: '${transaction.idempotencyKey}:line:${line.uuid}',
        ),
      );
    }

    final List<TypedResult> modifierRows =
        await (_database.select(_database.orderModifiers).join(<Join>[
                innerJoin(
                  _database.transactionLines,
                  _database.transactionLines.id.equalsExp(
                    _database.orderModifiers.transactionLineId,
                  ),
                ),
              ])
              ..where(
                _database.transactionLines.transactionId.equals(transaction.id),
              )
              ..orderBy(<OrderingTerm>[
                OrderingTerm.asc(_database.transactionLines.id),
                OrderingTerm.asc(_database.orderModifiers.id),
              ]))
            .get();

    for (final TypedResult row in modifierRows) {
      final db.OrderModifier modifier = row.readTable(_database.orderModifiers);
      final Map<String, Object?> modifierPayload =
          await _buildOrderModifierPayload(modifier.uuid) ??
          (throw StateError(
            'Order modifier payload missing for ${modifier.uuid}.',
          ));
      records.add(
        SyncGraphRecord(
          tableName: 'order_modifiers',
          recordUuid: modifier.uuid,
          payload: modifierPayload,
          idempotencyKey:
              '${transaction.idempotencyKey}:modifier:${modifier.uuid}',
        ),
      );
    }

    final db.Payment? payment =
        await (_database.select(_database.payments)..where(
              (db.$PaymentsTable t) => t.transactionId.equals(transaction.id),
            ))
            .getSingleOrNull();
    if (transaction.status == 'paid' && payment == null) {
      throw StateError(
        'PAID transaction graph requires a payment snapshot for $transactionUuid.',
      );
    }
    if (payment != null) {
      final Map<String, Object?> paymentPayload =
          await _buildPaymentPayload(payment.uuid) ??
          (throw StateError('Payment payload missing for ${payment.uuid}.'));
      records.add(
        SyncGraphRecord(
          tableName: 'payments',
          recordUuid: payment.uuid,
          payload: paymentPayload,
          idempotencyKey:
              '${transaction.idempotencyKey}:payment:${payment.uuid}',
        ),
      );
    }

    return SyncTransactionGraph(
      transactionUuid: transaction.uuid,
      transactionIdempotencyKey: transaction.idempotencyKey,
      records: records,
    );
  }

  Future<Map<String, Object?>?> buildPayload({
    required String tableName,
    required String recordUuid,
  }) async {
    switch (tableName) {
      case 'transactions':
        return _buildTransactionPayload(recordUuid);
      case 'transaction_lines':
        return _buildTransactionLinePayload(recordUuid);
      case 'order_modifiers':
        return _buildOrderModifierPayload(recordUuid);
      case 'payments':
        return _buildPaymentPayload(recordUuid);
      default:
        throw ArgumentError.value(
          tableName,
          'tableName',
          'Unsupported sync table',
        );
    }
  }

  Future<Map<String, Object?>?> _buildTransactionPayload(String uuid) async {
    final db.Transaction? row =
        await (_database.select(_database.transactions)
              ..where((db.$TransactionsTable t) => t.uuid.equals(uuid)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    return <String, Object?>{
      'uuid': row.uuid,
      'shift_local_id': row.shiftId,
      'user_local_id': row.userId,
      'table_number': row.tableNumber,
      'status': row.status,
      'subtotal_minor': row.subtotalMinor,
      'modifier_total_minor': row.modifierTotalMinor,
      'total_amount_minor': row.totalAmountMinor,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'paid_at': row.paidAt?.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'cancelled_at': row.cancelledAt?.toUtc().toIso8601String(),
      'cancelled_by_local_id': row.cancelledBy,
      'kitchen_printed': row.kitchenPrinted,
      'receipt_printed': row.receiptPrinted,
    };
  }

  Future<Map<String, Object?>?> _buildTransactionLinePayload(
    String uuid,
  ) async {
    final db.TransactionLine? row =
        await (_database.select(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) => t.uuid.equals(uuid)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    final db.Transaction? transaction =
        await (_database.select(_database.transactions)..where(
              (db.$TransactionsTable t) => t.id.equals(row.transactionId),
            ))
            .getSingleOrNull();
    if (transaction == null) {
      return null;
    }

    return <String, Object?>{
      'uuid': row.uuid,
      'transaction_uuid': transaction.uuid,
      'product_local_id': row.productId,
      'product_name': row.productName,
      'unit_price_minor': row.unitPriceMinor,
      'quantity': row.quantity,
      'line_total_minor': row.lineTotalMinor,
    };
  }

  Future<Map<String, Object?>?> _buildOrderModifierPayload(String uuid) async {
    final db.OrderModifier? row =
        await (_database.select(_database.orderModifiers)
              ..where((db.$OrderModifiersTable t) => t.uuid.equals(uuid)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    final db.TransactionLine? line =
        await (_database.select(_database.transactionLines)..where(
              (db.$TransactionLinesTable t) =>
                  t.id.equals(row.transactionLineId),
            ))
            .getSingleOrNull();
    if (line == null) {
      return null;
    }

    return <String, Object?>{
      'uuid': row.uuid,
      'transaction_line_uuid': line.uuid,
      'action': row.action,
      'item_name': row.itemName,
      'extra_price_minor': row.extraPriceMinor,
    };
  }

  Future<Map<String, Object?>?> _buildPaymentPayload(String uuid) async {
    final db.Payment? row = await (_database.select(
      _database.payments,
    )..where((db.$PaymentsTable t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final db.Transaction? transaction =
        await (_database.select(_database.transactions)..where(
              (db.$TransactionsTable t) => t.id.equals(row.transactionId),
            ))
            .getSingleOrNull();
    if (transaction == null) {
      return null;
    }

    return <String, Object?>{
      'uuid': row.uuid,
      'transaction_uuid': transaction.uuid,
      'method': row.method,
      'amount_minor': row.amountMinor,
      'paid_at': row.paidAt.toUtc().toIso8601String(),
    };
  }
}

class SyncTransactionGraph {
  const SyncTransactionGraph({
    required this.transactionUuid,
    required this.transactionIdempotencyKey,
    required this.records,
  });

  final String transactionUuid;
  final String transactionIdempotencyKey;
  final List<SyncGraphRecord> records;
}

class SyncGraphRecord {
  const SyncGraphRecord({
    required this.tableName,
    required this.recordUuid,
    required this.payload,
    required this.idempotencyKey,
  });

  final String tableName;
  final String recordUuid;
  final Map<String, Object?> payload;
  final String idempotencyKey;

  ({String tableName, String recordUuid}) get queueRef =>
      (tableName: tableName, recordUuid: recordUuid);
}
