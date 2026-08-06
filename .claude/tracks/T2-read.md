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

> Durum kodları: `[ ]` yapılmadı · `[~]` kısmi · `[x]` bitti ·
> `[!]` **veri/kod hazır, arayüze bağlanmamış**
> Son denetim: **2026-08-06** (koddan doğrulandı).

---

## Aşama 1 — Okuma temeli (BİTTİ)

- [x] T2.1 `ReadController` (`Notifier`) — `idle / scanning / success / failure`
- [~] T2.2 `ReadPage` boş durum — büyük tarama düğmesi (FAB) + `EmptyState` var;
      **"son 3 okuma" listesi yok** (geçmişe erişim gerektirir)
- [x] T2.3 Tarama alt sayfası bağlandı (`NfcScanSheet`)
- [x] T2.4 `TagInfoView` — UID (hex / ters hex / ondalık), kopyala düğmeleri
- [x] T2.5 Teknoloji rozetleri listesi (`TagBadge` wrap)
- [x] T2.6 Yonga tanımlama gösterimi — model, üretici, toplam/kullanıcı bellek,
      ATQA, SAK
- [x] T2.7 Kapasite göstergesi (`CapacityBar`)
- [x] T2.8 Durum rozetleri: yazılabilir · salt-okunur · biçimlendirilmiş ·
      şifre korumalı

## Aşama 2 — NDEF gösterimi

- [x] T2.9 `_RecordCard` — tip ikonu + başlık + özet
- [x] T2.10 Kayıt genişletme: TNF, tip, id, payload (hex + metin)
- [x] T2.11 Kayıt tipine göre zengin gösterim — `NdefConverter.decode` ile
      `NdefContent` üzerinden (kendi ayrıştırıcı yazılmadı)
- [~] T2.12 İçerik eylemleri — `RecordContentActions` ile URL/arama/tel/SMS/
      e-posta/harita var. "WiFi'ye bağlan" yalnızca SSID/parola diyaloğu
      gösteriyor (native entegrasyon olmadan otomatik bağlanma yapılamaz)
- [~] T2.13 Paylaşma — **tüm okuma sonucu** JSON olarak paylaşılıyor,
      **tek kayıt** paylaşımı yalnızca vCard için var

## Aşama 3 — Teknik görünüm

- [x] T2.14 `HexDumpView` bağlandı — sayfa/blok numaralı, ASCII sütunlu
- [x] T2.15 Yapılandırma sayfaları çözümlemesi — `TagInfoView` içinde
      "Yapılandırma" bölümü: AUTH0 (koruma başlangıç sayfası), PROT kapsamı,
      AUTHLIM, NFC sayacı, MIRROR modu + sayfa/byte, güçlü modülasyon.
      CFGLCK açıksa ayrıca tehlike rozeti gösterilir.
- [x] T2.16 Kilit byte'ları görünümü — "Kilit durumu" bölümü: kilitli
      sayfalar aralık biçiminde (`4-9, 12`), block-lock sayfaları, CC kilidi
      ve kalıcı salt-okunur rozeti.
- [x] T2.17 Sayaç değeri gösterimi (`info.counterValue`)
- [~] T2.18 ECC imza gösterimi eklendi — "Orijinallik imzası" bölümü ham
      imzayı hex olarak gösteriyor ve neden doğrulanamadığını açıklıyor.
      **Doğrulama sonucu hâlâ yok:** NXP genel anahtarı eksik (bkz. T4.12).
      Anahtar girildiğinde bu bölüme geçerli/geçersiz rozeti eklenmeli.
- [ ] T2.19 MIFARE Classic sektör görünümü — sektör/blok ağacı, erişim bitleri
- [x] T2.20 Okuma sonucunu JSON olarak dışa aktar

## Aşama 4 — Sürekli mod

- [x] T2.21 Sürekli tarama modu — arka arkaya etiket, sayaç, liste
- [~] T2.22 Aynı etiketi tekrar okuma engeli — `ContinuousReadController`
      art arda aynı UID'yi atlıyor ama **sabit davranış**.
      `AppSettings.duplicateScanCooldown` (3 sn) alanı mevcut ama
      **hiç kullanılmıyor**; süre bazlı engel ve ayar UI'ı yok.

## Aşama 5 — Geçmiş (`feature_history`)

- [x] T2.23 `HistoryController` — `HistoryRepository` arayüzü üzerinden
- [ ] T2.24 Zaman gruplu liste (Bugün / Dün / Bu hafta / Daha eski) —
      şu an düz liste
- [x] T2.25 Arama + yonga ailesi filtre çipleri
- [~] T2.26 Uzun basarak eylem menüsü var; **kaydırarak silme ve çoklu
      seçim yok**
- [x] T2.27 Geçmiş detay ekranı
- [x] T2.28 Takma ad verme / düzenleme
- [x] T2.29 Dump arşivi sekmesi (liste / yeniden adlandır / dışa aktar / sil)
- [x] T2.30 Toplu dışa aktarma / içe aktarma (JSON)
- [x] T2.31 "Yazma ekranına yükle" — rota parametresi ile

## Aşama 6 — Test (HİÇBİRİ YAPILMADI)

- [ ] T2.32 `ReadController` birim testi (`FakeNfcSessionService` ile)
- [ ] T2.33 `HistoryController` birim testi (sahte repository)
- [ ] T2.34 Widget testi: okuma akışı mutlu yol + etiket kayboldu

Not: `feature_read` altında yalnızca `tag_info_json_test` ve
`wifi_credentials_test` var — ikisi de saf dönüşüm testi, controller testi değil.

---

## Notlar

- `feature_write`'a veri geçirmek için rota parametresi kullan:
  `context.go('/write?fromHistory=<id>')`. Kardeş paket import'u yasak.
- `ndef_codec` çözücüleri T3'ün sorumluluğunda. Eksik bir çözücü varsa
  `state/progress.md` → "Engeller" bölümüne yaz, kendin yazma.
- T2.15/T2.16/T2.18 **kapatıldı** — üç bölüm de `TagInfoView` içinde.
  Bu bölümler yalnızca **derin okumada** dolar; ayarlardan "okurken tam
  döküm al" kapalıysa kullanıcı hiç görmez. Sıradaki iş T2.19 (MIFARE
  sektör görünümü) ve Aşama 6 testleri.
- ⚠️ `ndef_codec`'e `WifiContent` eklendi (T3.18): WSC yükleri artık
  `MimeContent` değil `WifiContent` olarak çözülüyor. `RecordContentActions`
  ve `tag_info_view` güncellendi. Yeni `NdefContent` tipi geldiğinde
  `_iconFor` / `_titleFor` exhaustive `switch`'leri kırılır — bu bilinçli.
