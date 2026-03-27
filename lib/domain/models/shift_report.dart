class ShiftReport {
  const ShiftReport({
    required this.shiftId,
    required this.paidCount,
    required this.paidTotalMinor,
    required this.openCount,
    required this.openTotalMinor,
    required this.cancelledCount,
    required this.cashCount,
    required this.cashTotalMinor,
    required this.cardCount,
    required this.cardTotalMinor,
  });

  final int shiftId;
  final int paidCount;
  final int paidTotalMinor;
  final int openCount;
  final int openTotalMinor;
  final int cancelledCount;
  final int cashCount;
  final int cashTotalMinor;
  final int cardCount;
  final int cardTotalMinor;

  ShiftReport copyWith({
    int? shiftId,
    int? paidCount,
    int? paidTotalMinor,
    int? openCount,
    int? openTotalMinor,
    int? cancelledCount,
    int? cashCount,
    int? cashTotalMinor,
    int? cardCount,
    int? cardTotalMinor,
  }) {
    return ShiftReport(
      shiftId: shiftId ?? this.shiftId,
      paidCount: paidCount ?? this.paidCount,
      paidTotalMinor: paidTotalMinor ?? this.paidTotalMinor,
      openCount: openCount ?? this.openCount,
      openTotalMinor: openTotalMinor ?? this.openTotalMinor,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      cashCount: cashCount ?? this.cashCount,
      cashTotalMinor: cashTotalMinor ?? this.cashTotalMinor,
      cardCount: cardCount ?? this.cardCount,
      cardTotalMinor: cardTotalMinor ?? this.cardTotalMinor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShiftReport &&
        other.shiftId == shiftId &&
        other.paidCount == paidCount &&
        other.paidTotalMinor == paidTotalMinor &&
        other.openCount == openCount &&
        other.openTotalMinor == openTotalMinor &&
        other.cancelledCount == cancelledCount &&
        other.cashCount == cashCount &&
        other.cashTotalMinor == cashTotalMinor &&
        other.cardCount == cardCount &&
        other.cardTotalMinor == cardTotalMinor;
  }

  @override
  int get hashCode => Object.hash(
    shiftId,
    paidCount,
    paidTotalMinor,
    openCount,
    openTotalMinor,
    cancelledCount,
    cashCount,
    cashTotalMinor,
    cardCount,
    cardTotalMinor,
  );
}
