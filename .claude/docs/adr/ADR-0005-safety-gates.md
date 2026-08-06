# ADR-0005 — Geri alınamaz işlemler için güvenlik kapıları

**Durum:** Kabul edildi · 2026-08-03

## Bağlam

Bu uygulama etiketi kalıcı olarak bozabilir:

| İşlem | Sonuç |
|---|---|
| Statik/dinamik kilit | Sayfa sonsuza dek yazılamaz |
| `CFGLCK = 1` | Yapılandırma sonsuza dek dondurulur |
| `AUTHLIM > 0` + yanlış denemeler | Etiket tamamen erişilemez |
| `AUTH0` yanlış sıra | Parola yazılamadan etiket kilitlenir |
| CC yanlış yazımı | Etiket NDEF olarak okunamaz |

Kullanıcı çoğu zaman ne yaptığını tam bilmiyor. Tek yanlış dokunuş = çöp etiket.

## Karar

Dört katmanlı koruma:

**1. Kod katmanı (`tag_ops`)**
Tehlikeli her işlem, `DangerAck` tipinde açık bir onay nesnesi ister.
UI'dan gelmeyen bir çağrı derlenmez:

```dart
Future<Result<void>> makeReadOnly({required DangerAck ack});
```

**2. Otomatik yedek**
Yıkıcı işlemden önce `tag_ops` tam dump alır ve `storage`'a yazar.
Yedek alınamıyorsa işlem varsayılan olarak **iptal edilir**
(kullanıcı açıkça "yedeksiz devam et" derse geçilir).

**3. UI onayı (`DangerDialog`)**
- Ne olacağı düz Türkçe
- "GERİ ALINAMAZ" rozeti
- Hedef etiket UID'si
- Kaydırarak onay (kazara dokunma engeli)

**4. Uzman modu kapısı**
En tehlikeli üçlü — `CFGLCK`, sayfa bazlı kilitleme, `AUTHLIM` —
ayarlardan uzman modu açılmadan **arayüzde görünmez**.

## Sonuçlar

- ✅ Kazara etiket bozma pratikte imkânsız.
- ✅ Bozulsa bile dump'tan geri yükleme şansı var (kilitlenmemişse).
- ⚠️ Uzman kullanıcı için fazladan tıklama. Uzman modu bunu hafifletir.
- ⚠️ `DangerAck` tipi test yazımını biraz uzatır; `DangerAck.forTest()`
  yardımcısı sağlanır.

## Kural

**Yeni bir yıkıcı işlem eklerken bu dört kapıdan geçmiyorsa PR reddedilir.**

---

## Uygulama durumu — 2026-08-06 denetimi

Karar geçerli; **dört kapı da uygulandı.**

| Kapı | Durum |
|---|---|
| 1. `DangerAck` kod katmanı | ✅ Tüm yıkıcı `TagOperations` metodları istiyor |
| 2. **Otomatik yedek** | ✅ Uygulandı (2026-08-06) |
| 3. `DangerDialog` UI onayı | ✅ Kaydırarak onay + UID + risk rozeti |
| 4. Uzman modu kapısı | ✅ `ToolCatalog.byCategory(expertMode:)` |

2. kapı `ToolDetailPage._ensureBackup` / `_saveBackup` ile uygulandı:
yıkıcı işlemden önce `readMemory()` alınıp `DumpRepository.add()` ile
arşive yazılır (`DumpReason.automaticBackup`). Yedek alınamazsa işlem
**varsayılan olarak iptal** edilir; kullanıcı açıkça "Yedeksiz devam et"
derse geçilir. Üç akış da kapsanır: normal yıkıcı araçlar, "Etiketi
kopyala" ve "Magic kart klonla" — son ikisinde **hedef** etiket yedeklenir.

`DangerAck.backupTaken` artık gerçek sonucu taşır. Önceden bu alan her zaman
onay diyaloğundaki anahtarın değeriydi; yedek alınmadığı halde `true`
görünüyordu — kayıt yanıltıcıydı.

**Yeni yıkıcı araç eklerken** `_ensureBackup` çağrısını atlama; dördüncü
kapı olan uzman modu kadar zorunludur.
