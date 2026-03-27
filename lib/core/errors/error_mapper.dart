import 'exceptions.dart';

class ErrorMapper {
  const ErrorMapper._();

  static String toUserMessage(Object error) {
    if (error is ShiftNotActiveException) {
      return 'Aktif shift yok. İlk giriş yapan kullanıcı yeni shift başlatır.';
    }
    if (error is ShiftClosedException) {
      return 'Shift zaten kapatılmış.';
    }
    if (error is ShiftMismatchException) {
      return 'Sipariş aktif shift\'e ait değil. Ödeme alınamaz.';
    }
    if (error is CashierPreviewLockedException) {
      return 'Cashier gün sonu raporu alınmış. Yeni sipariş ve ödeme tüm cashier\'lar için kapalı. Admin final kapanış yapmalı.';
    }
    if (error is CashierShiftClosedException) {
      return 'Cashier tarafı kapanmış durumda. Final kapanış admin tarafından yapılmalı.';
    }
    if (error is ShiftAlreadyOpenException) {
      return 'Zaten açık bir shift var.';
    }
    if (error is OpenOrdersExistException) {
      return '${error.count} adet açık sipariş var. Önce kapatın veya iptal edin.';
    }
    if (error is InvalidStateTransitionException) {
      return 'Bu işlem şu anda yapılamaz.';
    }
    if (error is DuplicatePaymentException) {
      return 'Bu siparişe zaten ödeme yapılmış.';
    }
    if (error is PaymentAmountMismatchException) {
      return 'Ödeme tutarı eşleşmiyor.';
    }
    if (error is UnauthorisedException) {
      return 'Bu işlem için yetkiniz yok.';
    }
    if (error is EmptyCartException) {
      return 'Sepet boş. Ürün ekleyin.';
    }
    if (error is CheckoutFailedException) {
      return 'Sipariş oluşturulamadı. Tekrar deneyin.';
    }
    if (error is NotFoundException) {
      return 'Kayıt bulunamadı.';
    }
    if (error is ValidationException) {
      return error.message;
    }
    if (error is AppException) {
      return error.message;
    }
    return 'Beklenmeyen bir hata oluştu. Tekrar deneyin.';
  }
}
