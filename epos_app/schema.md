# EPOS Veritabanı Şeması — Drift (SQLite) Referans Belgesi

> **Bu belge `CLAUDE.md` ile birebir uyumlu tek kaynak doğruluğudur.**
> Bir geliştirici sadece bunu okuyarak `app_database.dart` dosyasını doğru yazabilmelidir.

---

## Genel Kurallar

### Proje Kapsamı
- Tek lokasyon, küçük kafe/restoran.
- Aynı anda yalnızca bir aktif shift vardır.
- Gün içinde birden fazla kullanıcı login olabilir.
- Tek Bluetooth ESC/POS yazıcı vardır.
- Split payment YOK. Kısmi ödeme YOK.
- Ayrı order type alanı YOK. `table_number` nullable: null = masa atanmamış sipariş.
- Modifier group yapısı YOK. Düz modifier modeli.
- Tax/VAT/discount/service charge YOK. Gerekirse migration ile eklenir.

### Primary Key Stratejisi
- Tüm tabloların primary key'i `INTEGER autoIncrement`.
- FK ilişkileri INTEGER ID üzerinden kurulur.
- Sync edilecek tablolarda ek `uuid TEXT UNIQUE NOT NULL` alanı bulunur.
- Bu uuid kayıt oluşturulduğunda UUID v4 ile doldurulur.
- Supabase'e uuid üzerinden UPSERT yapılır. Local integer ID gönderilmez.

### Para Birimi Kuralı — KRİTİK
**Tüm para alanları INTEGER olarak minor units (kuruş/pence) cinsinden tutulur.**

```text
£12.50 → 1250
£0.00  → 0
£1.00  → 100
```

- `REAL` / `double` / `float` para alanı için YASAKTIR.
- Binary floating point sapması (`0.1 + 0.2 != 0.3`) raporları, toplam kontrollerini ve ödeme eşleştirmesini bozar.
- UI'da gösterim için `currency_formatter.dart` kullanılır: `1250 → £12.50`.

### Text Enum Kuralı
Tüm sınırlı değerli text alanları CHECK constraint ile korunur.  
Drift'te `customConstraint` kullanılır.

---

## Tablolar (12 Adet)

### 1. users

Admin ve cashier kullanıcıları.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| name | TEXT | NOT NULL | |
| pin | TEXT | nullable | Tüm operasyonel kullanıcılar PIN ile giriş yapar. Uygulama katmanında hashlenip yazılır. |
| password | TEXT | nullable | Ayrı admin şifre akışı için rezerv alan; aktif operasyon girişi PIN ile yapılır. |
| role | TEXT | NOT NULL, CHECK (role IN ('admin','cashier')) | |
| is_active | BOOLEAN | DEFAULT true | |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |

**Not:** `pin` ve `password` DB'de yalnızca hashlenmiş tutulur.

**UUID:** Yok. Sync edilmeyen yerel sistem tablosu.

---

### 2. categories

Ürün kategorileri.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| name | TEXT | NOT NULL | |
| image_url | TEXT | nullable | Supabase Storage URL |
| sort_order | INTEGER | DEFAULT 0 | |
| is_active | BOOLEAN | DEFAULT true | |

**UUID:** Yok.

---

### 3. products

Satılabilir ürünler.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| category_id | INTEGER | NOT NULL, FK → categories.id | |
| name | TEXT | NOT NULL | |
| price_minor | INTEGER | NOT NULL, CHECK (price_minor >= 0) | Fiyat (pence). £8.50 → 850 |
| image_url | TEXT | nullable | |
| has_modifiers | BOOLEAN | DEFAULT false | |
| is_active | BOOLEAN | DEFAULT true | |
| sort_order | INTEGER | DEFAULT 0 | |

**UUID:** Yok.

---

### 4. product_modifiers

Ürüne bağlı düz modifier seçenekleri.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| product_id | INTEGER | NOT NULL, FK → products.id | |
| name | TEXT | NOT NULL | |
| type | TEXT | NOT NULL, CHECK (type IN ('included','extra')) | |
| extra_price_minor | INTEGER | DEFAULT 0, CHECK (extra_price_minor >= 0) | |
| is_active | BOOLEAN | DEFAULT true | |

**UUID:** Yok.

---

### 5. shifts

Günlük operasyon kaydı.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| opened_by | INTEGER | NOT NULL, FK → users.id | İlk başarılı login ile açan kullanıcı |
| opened_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |
| closed_by | INTEGER | nullable, FK → users.id | Final close yapan admin |
| closed_at | DATETIME | nullable | |
| cashier_previewed_at | DATETIME | nullable | Cashier masked EOD zamanı |
| cashier_previewed_by | INTEGER | nullable, FK → users.id | Cashier masked EOD alan kullanıcı |
| status | TEXT | DEFAULT 'open', CHECK (status IN ('open','closed')) | |

**Kritik Kurallar:**
- Aynı anda SADECE BİR shift açık olabilir.
- Aktif shift yoksa ilk başarılı login (admin veya cashier) shift açar.
- Cashier preview alanları gerçek lifecycle state değildir; operasyonel preview flag'idir.
- Gerçek shift kapanışı sadece admin final close ile olur.

**UUID:** Yok.

---

### 6. transactions

Her sipariş kaydı. State machine: OPEN → PAID | CANCELLED.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| uuid | TEXT | UNIQUE NOT NULL | |
| shift_id | INTEGER | NOT NULL, FK → shifts.id | Aktif shift'in ID'si |
| user_id | INTEGER | NOT NULL, FK → users.id | Siparişi oluşturan kullanıcı |
| table_number | INTEGER | nullable | Sipariş anında boş olabilir, sonradan eklenebilir |
| status | TEXT | DEFAULT 'open', CHECK (status IN ('open','paid','cancelled')) | |
| subtotal_minor | INTEGER | DEFAULT 0, CHECK (subtotal_minor >= 0) | Ürün satır toplamları (pence) |
| modifier_total_minor | INTEGER | DEFAULT 0, CHECK (modifier_total_minor >= 0) | Modifier toplamı (pence) |
| total_amount_minor | INTEGER | DEFAULT 0, CHECK (total_amount_minor >= 0) | Son toplam (pence) |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |
| paid_at | DATETIME | nullable | |
| updated_at | DATETIME | NOT NULL | |
| cancelled_at | DATETIME | nullable | |
| cancelled_by | INTEGER | nullable, FK → users.id | |
| idempotency_key | TEXT | UNIQUE NOT NULL | |
| kitchen_printed | BOOLEAN | DEFAULT false | |
| receipt_printed | BOOLEAN | DEFAULT false | |

**Kurallar:**
- `subtotal_minor`, `modifier_total_minor`, `total_amount_minor` snapshot'tır.
- Sipariş finalize edilirken `order_service.dart` tarafından tek noktadan hesaplanır.
- `table_number` nullable'dır; masa sipariş anında belli olmayabilir.

**UUID:** Var.

---

### 7. transaction_lines

Sipariş kalemleri.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| uuid | TEXT | UNIQUE NOT NULL | |
| transaction_id | INTEGER | NOT NULL, FK → transactions.id | |
| product_id | INTEGER | NOT NULL, FK → products.id | |
| product_name | TEXT | NOT NULL | Snapshot |
| unit_price_minor | INTEGER | NOT NULL, CHECK (unit_price_minor >= 0) | Snapshot |
| quantity | INTEGER | DEFAULT 1, CHECK (quantity > 0) | |
| line_total_minor | INTEGER | NOT NULL, CHECK (line_total_minor >= 0) | `unit_price_minor * quantity + modifier extra'lar` |

**UUID:** Var.

---

### 8. order_modifiers

Sipariş modifier snapshot'ları.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| uuid | TEXT | UNIQUE NOT NULL | |
| transaction_line_id | INTEGER | NOT NULL, FK → transaction_lines.id | |
| action | TEXT | NOT NULL, CHECK (action IN ('remove','add')) | |
| item_name | TEXT | NOT NULL | Snapshot |
| extra_price_minor | INTEGER | DEFAULT 0, CHECK (extra_price_minor >= 0) | Snapshot |

**UUID:** Var.

---

### 9. payments

Ödeme kaydı. Transaction başına TAM OLARAK BİR payment.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| uuid | TEXT | UNIQUE NOT NULL | |
| transaction_id | INTEGER | UNIQUE NOT NULL, FK → transactions.id | |
| method | TEXT | NOT NULL, CHECK (method IN ('cash','card')) | |
| amount_minor | INTEGER | NOT NULL, CHECK (amount_minor > 0) | |
| paid_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |

**Kurallar:**
- `payments.amount_minor == transactions.total_amount_minor`
- `transaction.status != OPEN` ise payment INSERT reddedilir
- Payment + PAID transition aynı DB transaction içinde gerçekleşir

**UUID:** Var.

---

### 10. report_settings

Z report visibility ayarı.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| visibility_ratio | REAL | DEFAULT 1.0, CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0) | Cashier için görünür oran |
| updated_by | INTEGER | nullable, FK → users.id | |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | |

**Kullanım:**
- Admin gerçek raporu görür.
- Cashier aynı formatta ama maskeli değerlerle görür.
- Printer da aynı görünürlük pipeline'ını kullanır.

**UUID:** Yok.

---

### 11. printer_settings

Bluetooth ESC/POS printer konfigürasyonu.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| device_name | TEXT | NOT NULL | |
| device_address | TEXT | NOT NULL | |
| paper_width | INTEGER | DEFAULT 80, CHECK (paper_width IN (58,80)) | |
| is_active | BOOLEAN | DEFAULT true | |

**UUID:** Yok.

---

### 12. sync_queue

Offline-first sync kuyruğu.

| Kolon | Tip | Constraint | Açıklama |
|-------|-----|-----------|----------|
| id | INTEGER | PK autoIncrement | |
| table_name | TEXT | NOT NULL, CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments')) | |
| record_uuid | TEXT | NOT NULL | |
| operation | TEXT | NOT NULL, DEFAULT 'upsert', CHECK (operation IN ('upsert')) | |
| created_at | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP | |
| status | TEXT | NOT NULL, DEFAULT 'pending', CHECK (status IN ('pending','processing','synced','failed')) | |
| attempt_count | INTEGER | NOT NULL, DEFAULT 0 | |
| last_attempt_at | DATETIME | nullable | |
| synced_at | DATETIME | nullable | |
| error_message | TEXT | nullable | |

**Kurallar:**
- OPEN transaction'lar sync edilmez.
- PAID ve CANCELLED transaction'lar sync edilir.

**UUID:** Yok.

---

## UUID Özeti

| Tablo | UUID | Sync |
|-------|------|------|
| users | ❌ | ❌ |
| categories | ❌ | ❌ |
| products | ❌ | ❌ |
| product_modifiers | ❌ | ❌ |
| shifts | ❌ | ❌ |
| transactions | ✅ | ✅ |
| transaction_lines | ✅ | ✅ |
| order_modifiers | ✅ | ✅ |
| payments | ✅ | ✅ |
| report_settings | ❌ | ❌ |
| printer_settings | ❌ | ❌ |
| sync_queue | ❌ | ❌ |

---

## Index'ler

```text
idx_products_category       → products(category_id, is_active, sort_order)
idx_product_modifiers_prod  → product_modifiers(product_id, is_active)
idx_transactions_shift      → transactions(shift_id, status, created_at)
idx_transactions_user       → transactions(user_id, created_at)
idx_transaction_lines_tx    → transaction_lines(transaction_id)
idx_order_modifiers_line    → order_modifiers(transaction_line_id)
idx_payments_tx             → payments(transaction_id)
idx_shifts_status           → shifts(status, opened_at)
idx_sync_queue_status       → sync_queue(status, created_at)
```

---

## CHECK Constraint Özeti

```sql
-- users
CHECK (role IN ('admin','cashier'))

-- products
CHECK (price_minor >= 0)

-- product_modifiers
CHECK (type IN ('included','extra'))
CHECK (extra_price_minor >= 0)

-- shifts
CHECK (status IN ('open','closed'))

-- transactions
CHECK (status IN ('open','paid','cancelled'))
CHECK (subtotal_minor >= 0)
CHECK (modifier_total_minor >= 0)
CHECK (total_amount_minor >= 0)

-- transaction_lines
CHECK (unit_price_minor >= 0)
CHECK (quantity > 0)
CHECK (line_total_minor >= 0)

-- order_modifiers
CHECK (action IN ('remove','add'))
CHECK (extra_price_minor >= 0)

-- payments
CHECK (method IN ('cash','card'))
CHECK (amount_minor > 0)

-- report_settings
CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0)

-- printer_settings
CHECK (paper_width IN (58,80))

-- sync_queue
CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments'))
CHECK (operation IN ('upsert'))
CHECK (status IN ('pending','processing','synced','failed'))
```

---

## Drift Implementasyon Notları

### Para alanları Drift'te nasıl yazılır:
```dart
IntColumn get priceMinor => integer()();
IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();
```

### CHECK constraint Drift'te nasıl yazılır:
```dart
TextColumn get role => text()
    .customConstraint("NOT NULL CHECK (role IN ('admin','cashier'))")();

TextColumn get status => text()
    .withDefault(const Constant('open'))
    .customConstraint("NOT NULL CHECK (status IN ('open','paid','cancelled'))")();

IntColumn get totalAmountMinor => integer()
    .withDefault(const Constant(0))
    .customConstraint('NOT NULL CHECK (total_amount_minor >= 0)')();
```

### UNIQUE alanlar:
```text
transactions.uuid            → UNIQUE NOT NULL
transactions.idempotency_key → UNIQUE NOT NULL
transaction_lines.uuid       → UNIQUE NOT NULL
order_modifiers.uuid         → UNIQUE NOT NULL
payments.uuid                → UNIQUE NOT NULL
payments.transaction_id      → UNIQUE NOT NULL
```

---

## Kapsam Dışı — BİLİNÇLİ OLARAK DAHİL EDİLMEDİ

- `partially_paid` durumu
- Çoklu payment akışı
- Order type / takeaway / delivery ayrımı
- Modifier group yapısı
- Çoklu printer mimarisi
- Tax / VAT / discount / service charge
- Payment'ta `status`, `reference`, `provider`
- Müşteri adı alanı (open orders için bilinçli olarak kullanılmaz)

---

## Schema Değişiklik Prosedürü

```text
1. Migration planı çıkar: tablo, alan, constraint, mevcut veriye etki.
2. Destructive değişikliklerde explicit onay al.
3. schemaVersion artırma + migration dosyası oluşturma TEK ADIMDA.
4. Migration'da hem UP hem rollback stratejisi belirt.
5. app_database.dart güncellemesi migration dosyasından SONRA.
```

---

## Planned Menu Engine Schema Extension — Agreed Direction

Bu bölüm, repo gerçekliğini bozmadan bir sonraki migration'da eklenmesi planlanan menu engine genişletmesini tanımlar. Amaç set breakfast, choice, swap ve extras akışını DB seviyesinde açıklanabilir hale getirmektir.

### Yeni tablolar

#### `menu_settings`
Global menu policy ayarı. Repository aktif satırı kullanır.

- `id` INTEGER PK AUTOINCREMENT
- `free_swap_limit` INTEGER NOT NULL DEFAULT 2 CHECK `>= 0`
- `updated_by` INTEGER NULL FK `users.id`
- `updated_at` DATETIME NOT NULL DEFAULT current timestamp

Not:
- `max_swaps` alanı bu son karara göre gerekli değildir; 3. replacement ve sonrası `paid_swap` olarak devam eder.

#### `set_items`
Set ürünün default içeriğini tanımlar.

- `id` INTEGER PK AUTOINCREMENT
- `product_id` INTEGER NOT NULL FK `products.id`  -- set product
- `item_product_id` INTEGER NOT NULL FK `products.id` -- gerçek ürün
- `is_removable` BOOLEAN NOT NULL DEFAULT true
- `default_quantity` INTEGER NOT NULL DEFAULT 1 CHECK `> 0`
- `sort_order` INTEGER NOT NULL DEFAULT 0
- UNIQUE `(product_id, item_product_id)`

Not:
- Swap sadece `is_removable = true` set item'larında çalışır.
- Choice item'lar mümkünse `set_items` yerine `modifier_groups` üzerinden modellenmelidir.

#### `modifier_groups`
Choice group tanımı.

- `id` INTEGER PK AUTOINCREMENT
- `product_id` INTEGER NOT NULL FK `products.id`
- `name` TEXT NOT NULL
- `min_select` INTEGER NOT NULL DEFAULT 1 CHECK `>= 0`
- `max_select` INTEGER NOT NULL DEFAULT 1 CHECK `> 0`
- `included_quantity` INTEGER NOT NULL DEFAULT 1 CHECK `> 0`
- `sort_order` INTEGER NOT NULL DEFAULT 0
- CHECK `max_select >= min_select`
- UNIQUE `(product_id, name)`

Not:
- `included_quantity`, choice grubunun ücretsiz allowance miktarını taşır.
- Örnek: `Tea/Coffee -> included_quantity = 1`, `Toast/Bread -> included_quantity = 2`

### Mevcut tablolara planlanan eklemeler

#### `categories`
Removal discount için:

- `removal_discount_1_minor` INTEGER NOT NULL DEFAULT 0 CHECK `>= 0`
- `removal_discount_2_minor` INTEGER NOT NULL DEFAULT 0 CHECK `>= 0`

#### `product_modifiers`
Set / choice ayrımı için:

- `group_id` INTEGER NULL FK `modifier_groups.id`
- `type` CHECK `('included','extra','choice')`
- CHECK `((group_id IS NOT NULL AND type = 'choice') OR (group_id IS NULL AND type IN ('included','extra')))`

Not:
- Group içi karışık type desteklenmez. Group varsa bu kayıt choice davranışındadır.

#### `products`
Şimdilik override alanı zorunlu değil. Tek global `free_swap_limit` ile başlanabilir.

#### `transaction_lines`
Menu engine snapshot'ı için:

- `pricing_mode` TEXT NOT NULL DEFAULT `standard` CHECK `('standard','set')`
- `removal_discount_total_minor` INTEGER NOT NULL DEFAULT 0 CHECK `>= 0`

Not:
- Bu son karara göre `create_your_own` pricing mode plan dışıdır.

#### `order_modifiers`
Menu engine snapshot'ı için:

- `quantity` INTEGER NOT NULL DEFAULT 1 CHECK `> 0`
- `item_product_id` INTEGER NULL FK `products.id`
- `charge_reason` TEXT NULL CHECK `('extra_add','free_swap','paid_swap','included_choice','removal_discount')`
- `action` CHECK `('remove','add','choice')`

Davranış notu:
- `action = 'choice'` ise `charge_reason = 'included_choice'`
- `extra_add`, hem normal extra ekleme hem choice allowance aşımı için kullanılabilir
- Choice item hiçbir zaman `free_swap` veya `paid_swap` olamaz

### Menu engine semantic rules

#### Choice
- Choice item ücretsiz included seçim olarak tutulur
- Allowance aşılırsa aynı ürün ayrıca `extra_add` olarak ücretlenebilir
- Choice item swap hattına girmez

#### Swap
- Swap sadece removable set item remove edilip yerine ürün seçildiğinde oluşur
- İlk 2 replacement → `free_swap`
- 3. replacement ve sonrası → `paid_swap`

#### Extras
- Eşleşmemiş remove yoksa yapılan add → `extra_add`
- Limit yoktur

### Raporlama notu

`order_modifiers.item_product_id` ve `charge_reason` alanları rapor ve audit için kritiktir. Aynı ürün hem `included_choice` hem `extra_add` olarak görülebilir; bu hata değil, bağlam farkıdır.

