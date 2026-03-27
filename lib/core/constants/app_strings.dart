class AppStrings {
  const AppStrings._();

  static const String appName = 'EPOS';

  static const String loginTitle = 'PIN Giriş';
  static const String pinLabel = 'PIN';
  static const String loginButton = 'Giriş Yap';
  static const String loading = 'Yükleniyor...';
  static const String enterPin = 'PIN girin.';
  static const String loginFailed = 'Giriş başarısız.';
  static const String invalidPinOrInactiveUser =
      'Geçersiz PIN veya pasif kullanıcı.';
  static const String authLocked =
      'Çok fazla hatalı deneme. 30 saniye bekleyin.';

  static const String navPos = 'POS';
  static const String navOrders = 'Açık Siparişler';
  static const String navReports = 'Raporlar';
  static const String navShifts = 'Shift Yönetimi';
  static const String navSettings = 'Ayarlar';
  static const String navLogout = 'Çıkış';

  static const String shiftActive = 'Aktif Shift';
  static const String shiftInactive = 'Shift Yok';
  static const String shiftOpen = 'Shift Açık';
  static const String shiftClosed = 'Shift Kapalı';
  static const String recentShifts = 'Son Shiftler';
  static const String noShiftHistory = 'Henüz shift geçmişi yok';
  static const String adminOnlyShiftMessage =
      'Gerçek gün sonu kapanışı sadece admin tarafından yapılır.';
  static const String closeShiftConfirmation =
      'Final Z raporu ile shift kapatılacak.';
  static const String openOrdersBlockTitle =
      'Açık siparişler varken shift kapatılamaz';
  static const String goToOpenOrders = 'Açık Siparişlere Git';
  static const String shiftOpened = 'İlk giriş ile shift açıldı.';
  static const String shiftClosedMessage = 'Shift kapatıldı.';
  static const String lastClosedShift = 'Son Kapalı Shift';
  static const String openedBy = 'Açan';
  static const String closedBy = 'Kapatan';
  static const String cashierPreviewedBy = 'Cashier Preview';
  static const String cashierPreviewedAt = 'Cashier Preview Saati';
  static const String cashierPreviewPending = 'Cashier preview henüz alınmadı.';
  static const String openedAt = 'Açılış';
  static const String closedAt = 'Kapanış';
  static const String paidOrders = 'PAID Siparişler';
  static const String cancelledOrders = 'İPTAL Siparişler';

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
      'Aktif shift yok. İlk giriş yapan kullanıcı yeni shift başlatır.';
  static const String paymentBlockedShiftClosed =
      'Aktif shift olmadan açık siparişe ödeme alınamaz.';
  static const String cashierPreviewLock =
      'Cashier masked gün sonu raporu alındı. Final kapanış admin tarafından yapılmalı.';
  static const String salesLockedForCashier =
      'Cashier tarafı kapanmış durumda. Yeni sipariş ve ödeme kapalı.';
  static const String modifierLoadFailed = 'Modifier yüklenemedi.';
  static const String modifierNotFound = 'Modifier bulunamadı.';

  static const String confirmCancellation = 'Sipariş iptal edilsin mi?';
  static const String yes = 'Evet';
  static const String no = 'Hayır';
  static const String table = 'Masa';
  static const String time = 'Saat';
  static const String itemCount = 'Kalem';
  static const String statusOpen = 'OPEN';
  static const String statusClosed = 'CLOSED';
  static const String reportsTitle = 'Z Raporu';
  static const String paymentBreakdown = 'Ödeme Yöntemi Dağılımı';
  static const String noReportData = 'Rapor verisi bulunamadı.';
  static const String selectShift = 'Shift Seç';
  static const String totalOrders = 'Toplam Sipariş';
  static const String activeShiftMissing = 'Aktif shift yok';
  static const String reportForShift = 'Shift Raporu';
  static const String reportForLatestShift = 'Son Shift Raporu';
  static const String accessDenied = 'Yetkiniz yok.';
  static const String unknownUser = 'Bilinmeyen Kullanıcı';
  static const String maskedZReportAction = 'Maskeli Z Raporu Al';
  static const String finalZReportAction = 'Final Z Raporu Al ve Shifti Kapat';
  static const String maskedReportTaken = 'Cashier masked gün sonu raporu alındı.';
  static const String finalReportTaken =
      'Final Z raporu alındı ve shift kapatıldı.';
  static const String currentBusinessShift = 'Açık İşletme Shift’i';
  static const String noBusinessShift = 'Açık işletme shift’i yok';
  static const String autoShiftOpenHint =
      'Aktif shift yoksa ilk giriş yapan kullanıcı shift başlatır.';
  static const String finalCloseHint =
      'Gerçek kapanış yalnızca admin final Z raporu ile yapılır.';
  static const String visibilityRatioTitle = 'Cashier Görünürlük Oranı';
  static const String visibilityRatioHint =
      'Cashier raporunda gerçek rakamların ne kadarı görünsün?';
  static const String saveSettings = 'Kaydet';
  static const String settingsTitle = 'Ayarlar';
  static const String settingsSaved = 'Ayarlar kaydedildi.';
  static const String editTable = 'Masa Düzenle';
  static const String addTable = 'Masa Ekle';
  static const String clearTable = 'Masa Temizle';
  static const String tableNumberHint = 'Masa numarası';
  static const String tableUpdated = 'Masa numarası güncellendi.';
  static const String shiftMonitorTitle = 'Shift Durumu';
  static const String openShiftFromLogin =
      'Açılış artık giriş anında otomatik yapılır.';
  static const String closeShiftFromZReport =
      'Kapanış yalnızca Z raporu ekranından yapılır.';

  static String orderNumber(int id) => 'Order #$id';
  static String openShiftLabel(int shiftId) => 'Shift #$shiftId';
}
