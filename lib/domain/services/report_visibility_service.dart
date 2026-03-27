import '../models/shift_report.dart';
import '../models/user.dart';

class ReportVisibilityService {
  const ReportVisibilityService();

  int applyVisibilityRatio(int amountMinor, double ratio) {
    return _maskAmount(amountMinor, _normalizedRatio(ratio));
  }

  int visibleAmountForUser({
    required int amountMinor,
    required User user,
    required double ratio,
  }) {
    if (user.role == UserRole.admin) {
      return amountMinor;
    }
    return applyVisibilityRatio(amountMinor, ratio);
  }

  ShiftReport applyVisibilityToReport(
    ShiftReport raw,
    User user,
    double ratio,
  ) {
    if (user.role == UserRole.admin) {
      return raw;
    }

    final double safeRatio = _normalizedRatio(ratio);
    final int visiblePaidTotalMinor = _maskAmount(
      raw.paidTotalMinor,
      safeRatio,
    );
    final int visibleOpenTotalMinor = _maskAmount(
      raw.openTotalMinor,
      safeRatio,
    );
    final int visibleCashTotalMinor = _maskAmount(
      raw.cashTotalMinor,
      safeRatio,
    );
    final int visibleCardTotalMinor = _allocateRemainingTotal(
      maskedParentTotal: visiblePaidTotalMinor,
      firstChildMaskedTotal: visibleCashTotalMinor,
    );

    return raw.copyWith(
      paidTotalMinor: visiblePaidTotalMinor,
      openTotalMinor: visibleOpenTotalMinor,
      cashTotalMinor: visibleCashTotalMinor,
      cardTotalMinor: visibleCardTotalMinor,
    );
  }

  double _normalizedRatio(double ratio) {
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  int _maskAmount(int amountMinor, double ratio) {
    return (amountMinor * ratio).round();
  }

  int _allocateRemainingTotal({
    required int maskedParentTotal,
    required int firstChildMaskedTotal,
  }) {
    final int remainder = maskedParentTotal - firstChildMaskedTotal;
    return remainder < 0 ? 0 : remainder;
  }
}
