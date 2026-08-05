# T2 — Okuma & Geçmiş

**Sahip olduğun yollar:**
```
packages/features/feature_read/**
packages/features/feature_history/**
```

**Kullanabileceğin paketler:** `nfc_core`, `ndef_codec`, `design_system`,
`localization`, `shared_utils`
**YASAK:** `nfc_transport`, `tag_ops`, `storage`, diğer `feature_*`

**Okuman gerekenler:** `docs/02-feature-matrix.md` (A ve D bölümleri),
`docs/04-ui-ux-spec.md`, `docs/05-conventions.md`

---

## Aşama 1 — Okuma temeli

- [ ] T2.1 `ReadController` (`AsyncNotifier`) — tarama oturumu durumu:
      `idle / scanning / success(NfcTagInfo) / failure(NfcFailure)`
- [ ] T2.2 `ReadPage` — boş durum: büyük tarama düğmesi + son 3 okuma
- [ ] T2.3 Tarama alt sayfasını bağla (`NfcScanSheet`, design_system)
- [x] T2.4 `TagInfoView` — UID (hex / ters hex / ondalık), kopyala düğmeleri
- [ ] T2.5 Teknoloji rozetleri listesi (`techList` → okunabilir isim)
- [ ] T2.6 Yonga tanımlama gösterimi (`TagIdentity`) — model, üretici, bellek
- [ ] T2.7 Kapasite göstergesi — kullanılan / toplam, ilerleme çubuğu
- [ ] T2.8 Durum rozetleri: yazılabilir · salt-okunur · biçimlendirilmiş ·
      şifre korumalı

## Aşama 2 — NDEF gösterimi

- [ ] T2.9 `NdefRecordCard` — tip ikonu + başlık + özet
- [ ] T2.10 Kayıt genişletme: TNF, tip, id, payload (metin + hex sekmeli)
- [ ] T2.11 Kayıt tipine göre zengin gösterim (URL, WiFi, vCard, geo, tel...)
      — `ndef_codec` çözücülerini kullan, kendi ayrıştırıcını yazma
- [~] T2.12 İçerik eylemleri: URL aç, arama yap, ara/SMS gönder, kişi kaydet,
      WiFi'ye bağlan, konumu haritada aç — `RecordContentActions` ile hepsi
      var, "WiFi'ye bağlan" yalnızca SSID/parola diyaloğu gösteriyor
      (native platform entegrasyonu olmadan otomatik bağlanma yapılamaz)
- [ ] T2.13 Tek kayıt / tüm mesajı paylaş

## Aşama 3 — Teknik görünüm

- [ ] T2.14 `HexDumpView` — sayfa/blok numaralı, ASCII sütunlu, monospace
      (widget `design_system`'de; sen veriyi hazırla)
- [ ] T2.15 Yapılandırma sayfaları çözümlemesi: AUTH0, PROT, CFGLCK,
      AUTHLIM, MIRROR — insan-okunur satırlar
- [ ] T2.16 Kilit byte'ları görünümü — hangi sayfalar kilitli, görsel harita
- [ ] T2.17 Sayaç değeri gösterimi
- [ ] T2.18 ECC imza gösterimi + doğrulama sonucu (geçerli / geçersiz / bilinmiyor)
- [ ] T2.19 MIFARE Classic sektör görünümü — sektör/blok ağacı, erişim bitleri
- [x] T2.20 Okuma sonucunu JSON olarak dışa aktar

## Aşama 4 — Sürekli mod

- [x] T2.21 Sürekli tarama modu — arka arkaya etiket, sayaç, liste
- [~] T2.22 Aynı etiketi tekrar okuma engeli (UID bazlı, ayarlanabilir) —
      `ContinuousReadController` art arda aynı UID'yi atlıyor ama sabit
      davranış; ayarlanabilir bir seçenek yok

## Aşama 5 — Geçmiş (`feature_history`)

- [ ] T2.23 `HistoryController` — `HistoryRepository` arayüzü üzerinden
      (provider yer tutucusunu kendi paketinde ilan et, T1 override eder)
- [ ] T2.24 Geçmiş listesi — zaman gruplu (Bugün / Dün / Bu hafta / Daha eski)
- [ ] T2.25 Arama + filtre (etiket tipi, tarih aralığı, içerik tipi)
- [ ] T2.26 Satır kaydırarak silme, uzun basarak çoklu seçim
- [ ] T2.27 Geçmiş detay ekranı — okuma detayıyla aynı görünüm
- [ ] T2.28 Takma ad verme / düzenleme (UID → "Ofis kapısı")
- [ ] T2.29 Dump arşivi sekmesi — kayıtlı bellek dökümleri
- [ ] T2.30 Toplu dışa aktarma (JSON) / içe aktarma
- [ ] T2.31 "Yazma ekranına yükle" — geçmişteki NDEF'i yaz sekmesine taşı
      (doğrudan `feature_write`'ı import ETME — rota parametresi ile git)

## Aşama 6 — Test

- [ ] T2.32 `ReadController` birim testi (`FakeNfcSessionService` ile)
- [ ] T2.33 `HistoryController` birim testi (sahte repository)
- [ ] T2.34 Widget testi: okuma akışı mutlu yol + etiket kayboldu

---

## Notlar

- `feature_write`'a veri geçirmek için rota parametresi kullan:
  `context.go('/write?fromHistory=<id>')`. Kardeş paket import'u yasak.
- `ndef_codec` çözücüleri T3'ün sorumluluğunda. Eksik bir çözücü varsa
  `state/progress.md` → "Engeller" bölümüne yaz, kendin yazma.
