enum ShiftStatus { open, closed }

class Shift {
  const Shift({
    required this.id,
    required this.openedBy,
    required this.openedAt,
    required this.closedBy,
    required this.closedAt,
    required this.status,
  });

  final int id;
  final int openedBy;
  final DateTime openedAt;
  final int? closedBy;
  final DateTime? closedAt;
  final ShiftStatus status;

  Shift copyWith({
    int? id,
    int? openedBy,
    DateTime? openedAt,
    Object? closedBy = _unset,
    Object? closedAt = _unset,
    ShiftStatus? status,
  }) {
    return Shift(
      id: id ?? this.id,
      openedBy: openedBy ?? this.openedBy,
      openedAt: openedAt ?? this.openedAt,
      closedBy: closedBy == _unset ? this.closedBy : closedBy as int?,
      closedAt: closedAt == _unset ? this.closedAt : closedAt as DateTime?,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Shift &&
        other.id == id &&
        other.openedBy == openedBy &&
        other.openedAt == openedAt &&
        other.closedBy == closedBy &&
        other.closedAt == closedAt &&
        other.status == status;
  }

  @override
  int get hashCode =>
      Object.hash(id, openedBy, openedAt, closedBy, closedAt, status);
}

const Object _unset = Object();
