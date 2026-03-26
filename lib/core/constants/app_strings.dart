class AppStrings {
  const AppStrings._();

  static const String appName = 'EPOS';

  static const String loginTitle = 'PIN Giriş';
  static const String pinLabel = 'PIN';
  static const String loginButton = 'Giriş Yap';
  static const String loading = 'Yükleniyor...';
  static const String enterPin = 'PIN girin.';
  static const String loginFailed = 'Giriş başarısız.';

  static const String navPos = 'POS';
  static const String navOrders = 'Açık Siparişler';
  static const String navLogout = 'Çıkış';

  static const String shiftActive = 'Aktif Shift';
  static const String shiftInactive = 'Shift Yok';

  static const String allCategories = 'Tümü';
  static const String noCategories = 'Kategori bulunamadı';
  static const String noProductsInCategory = 'Bu kategoride ürün yok';

  static const String cartTitle = 'Sepet';
  static const String cartEmpty = 'Sepet boş — ürün ekleyin';
  static const String subtotal = 'Subtotal';
  static const String modifierTotal = 'Modifier Total';
  static const String total = 'TOTAL';
  static const String createOrder = 'Sipariş Ver';
  static const String payNow = 'Şimdi Öde';
  static const String clearCart = 'Temizle';

  static const String modifierDialogTitle = 'Modifier Seç';
  static const String includedModifiers = 'Included';
  static const String extraModifiers = 'Extra';
  static const String addToCart = 'Sepete Ekle';
  static const String cancel = 'İptal';

  static const String paymentTitle = 'Ödeme';
  static const String cash = 'Cash';
  static const String card = 'Card';
  static const String receivedAmount = 'Alınan Tutar';
  static const String change = 'Para Üstü';
  static const String pay = 'Öde';

  static const String openOrdersTitle = 'Açık Siparişler';
  static const String noOpenOrders = 'Açık sipariş bulunmuyor';
  static const String refresh = 'Yenile';
  static const String orderDetails = 'Sipariş Detayı';
  static const String kitchenPrint = 'Mutfak Yazdır';
  static const String receiptPrint = 'Fiş Yazdır';
  static const String selectOpenOrderFirst = 'Önce bir açık sipariş seçin.';

  static const String orderCreated = 'Sipariş oluşturuldu.';
  static const String orderCancelled = 'Sipariş iptal edildi.';
  static const String paymentCompleted = 'Ödeme tamamlandı.';
  static const String paymentFailedOrderOpen =
      'Ödeme başarısız. Sipariş açık olarak kaldı.';
  static const String printFailed = 'Yazdırma başarısız.';
  static const String kitchenPrintSent = 'Mutfak fişi gönderildi.';
  static const String receiptPrintSent = 'Fiş yazdırıldı.';
  static const String cancelFailed = 'İptal başarısız.';
  static const String shiftNotActiveError =
      "Aktif shift yok. Admin'e başvurun.";
  static const String modifierLoadFailed = 'Modifier yüklenemedi.';
  static const String modifierNotFound = 'Modifier bulunamadı.';

  static const String confirmCancellation = 'Sipariş iptal edilsin mi?';
  static const String yes = 'Evet';
  static const String no = 'Hayır';
  static const String table = 'Masa';
  static const String time = 'Saat';
  static const String itemCount = 'Kalem';
  static const String statusOpen = 'OPEN';

  static String orderNumber(int id) => 'Order #$id';
  static String openShiftLabel(int shiftId) => 'Shift #$shiftId';
}
