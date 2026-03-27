import 'shift.dart';

class ShiftSessionSnapshot {
  const ShiftSessionSnapshot({
    required this.backendOpenShift,
    required this.cashierPreviewActive,
    required this.salesLocked,
    required this.paymentsLocked,
    required this.lockReason,
  });

  final Shift? backendOpenShift;
  final bool cashierPreviewActive;
  final bool salesLocked;
  final bool paymentsLocked;
  final String? lockReason;

  Shift? get visibleShift => salesLocked ? null : backendOpenShift;
}
