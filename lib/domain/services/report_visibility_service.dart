import '../models/user.dart';

class ReportVisibilityService {
  const ReportVisibilityService();

  int applyVisibilityRatio(int amountMinor, double ratio) {
    final double safeRatio = ratio.clamp(0.0, 1.0).toDouble();
    return (amountMinor * safeRatio).round();
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
}
