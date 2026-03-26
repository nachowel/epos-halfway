abstract class AppException implements Exception {
  AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DatabaseException extends AppException {
  DatabaseException(super.message);
}

class ValidationException extends AppException {
  ValidationException(super.message);
}

class NotFoundException extends AppException {
  NotFoundException(super.message);
}

class ShiftAlreadyOpenException extends AppException {
  ShiftAlreadyOpenException()
    : super('A shift is already open. Close it before opening a new one.');
}

class ShiftNotActiveException extends AppException {
  ShiftNotActiveException()
    : super('No active shift. Please contact an admin.');
}

class OpenOrdersExistException extends AppException {
  OpenOrdersExistException(this.count)
    : super(
        '$count open order(s) exist. Close or cancel them before shift close.',
      );

  final int count;
}

class InvalidStateTransitionException extends AppException {
  InvalidStateTransitionException(super.message);
}

class UnauthorisedException extends AppException {
  UnauthorisedException(super.message);
}

class DuplicatePaymentException extends AppException {
  DuplicatePaymentException()
    : super('A payment already exists for this transaction.');
}

class PaymentAmountMismatchException extends AppException {
  PaymentAmountMismatchException({
    required this.expectedMinor,
    required this.actualMinor,
  }) : super(
         'Payment amount mismatch. expected=$expectedMinor actual=$actualMinor',
       );

  final int expectedMinor;
  final int actualMinor;
}

class EmptyCartException extends AppException {
  EmptyCartException() : super('Cart is empty.');
}

class CheckoutFailedException extends AppException {
  CheckoutFailedException(super.message);
}
