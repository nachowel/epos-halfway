import '../../core/errors/exceptions.dart';
import '../../data/repositories/shift_repository.dart';
import '../models/shift.dart';
import '../models/shift_session_snapshot.dart';
import '../models/transaction.dart';
import '../models/user.dart';

/// Central authority for shift/session rules.
///
/// Cashier preview lock is **shift-level**, not session-level:
/// once any cashier takes an end-of-day preview on a shift,
/// ALL cashier-role users are locked from creating orders and
/// taking payments on that shift — regardless of which cashier
/// took the preview or whether a different cashier logs in later.
///
/// Admin users are never affected by the cashier preview lock.
/// They can still create orders, take payments, view real reports,
/// and perform the final close on the same open shift.
class ShiftSessionService {
  const ShiftSessionService(this._shiftRepository);

  final ShiftRepository _shiftRepository;

  Future<Shift> ensureShiftStartedForLogin(User user) async {
    final Shift? existingOpenShift = await _shiftRepository.getOpenShift();
    if (existingOpenShift != null) {
      return existingOpenShift;
    }
    return _shiftRepository.openShift(user.id);
  }

  Future<Shift?> getBackendOpenShift() {
    return _shiftRepository.getOpenShift();
  }

  Future<Shift> requireBackendOpenShift() async {
    final Shift? openShift = await _shiftRepository.getOpenShift();
    if (openShift == null) {
      throw ShiftNotActiveException();
    }
    return openShift;
  }

  Future<ShiftSessionSnapshot> getSnapshotForUser(User? user) async {
    final Shift? openShift = await _shiftRepository.getOpenShift();
    if (openShift == null) {
      return const ShiftSessionSnapshot(
        backendOpenShift: null,
        cashierPreviewActive: false,
        salesLocked: true,
        paymentsLocked: true,
        lockReason: 'No active shift.',
      );
    }

    if (user == null) {
      return ShiftSessionSnapshot(
        backendOpenShift: openShift,
        cashierPreviewActive: openShift.hasCashierPreview,
        salesLocked: true,
        paymentsLocked: true,
        lockReason: null,
      );
    }

    final bool cashierPreviewActive = openShift.hasCashierPreview;
    final bool cashierLocked = _isCashierLocked(user, openShift);

    return ShiftSessionSnapshot(
      backendOpenShift: openShift,
      cashierPreviewActive: cashierPreviewActive,
      salesLocked: cashierLocked,
      paymentsLocked: cashierLocked,
      lockReason: cashierLocked
          ? CashierPreviewLockedException().message
          : null,
    );
  }

  /// Validates that [user] is allowed to create a new order.
  ///
  /// Throws [ShiftNotActiveException] if no shift is open.
  /// Throws [CashierPreviewLockedException] if the user is a cashier
  /// and any cashier has already taken an end-of-day preview on this shift.
  /// Admin users always pass this check.
  Future<void> ensureOrderCreationAllowed(User user) async {
    final Shift openShift = await requireBackendOpenShift();
    if (_isCashierLocked(user, openShift)) {
      throw CashierPreviewLockedException();
    }
  }

  /// Validates that [user] is allowed to take payment on [transaction].
  ///
  /// Throws [ShiftNotActiveException] if no shift is open.
  /// Throws [ShiftMismatchException] if the transaction's shift does not
  /// match the currently active shift.
  /// Throws [CashierPreviewLockedException] if the user is a cashier
  /// and the cashier preview lock is active on the shift.
  /// Admin users are never blocked by the preview lock.
  Future<void> ensurePaymentAllowed({
    required User user,
    required Transaction transaction,
  }) async {
    final Shift openShift = await requireBackendOpenShift();
    if (openShift.id != transaction.shiftId) {
      throw ShiftMismatchException(
        transactionShiftId: transaction.shiftId,
        activeShiftId: openShift.id,
      );
    }
    if (_isCashierLocked(user, openShift)) {
      throw CashierPreviewLockedException();
    }
  }

  /// Shift-level cashier lock: returns true when ALL of:
  /// 1. The user's role is cashier (admin is never locked)
  /// 2. The shift has a cashier preview recorded (by any cashier)
  bool _isCashierLocked(User user, Shift shift) {
    return user.role == UserRole.cashier && shift.hasCashierPreview;
  }
}
