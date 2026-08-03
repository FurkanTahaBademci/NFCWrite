# ADR-0001 — Yalnızca Android hedeflenecek

**Durum:** Kabul edildi · 2026-08-03

## Bağlam

Uygulamanın ana değeri düşük seviye etiket işlemlerinde: şifre koyma,
kilitleme, biçimlendirme, ham komut gönderme. Bunlar `transceive` erişimi
gerektirir.

- **Android:** `NfcA`, `MifareUltralight`, `MifareClassic`, `NfcV` sınıflarının
  hepsinde serbest `transceive`. Kısıt yok.
- **iOS (CoreNFC):** Yalnızca `NFCMiFareTag` üzerinden `sendMiFareCommand`,
  ve uygulamanın `com.apple.developer.nfc.readersession.formats` yetkisine
  sahip olması gerekir. `MifareClassic` yok. Arka planda tarama yok.
  Oturum her seferinde sistem penceresi açar.

## Karar

v1 yalnızca Android. iOS platform klasörü oluşturulmayacak.

## Sonuçlar

- ✅ Tüm "pro" özellikler kısıtsız uygulanabilir.
- ✅ Tek platform = daha az koşullu kod, daha hızlı ilerleme.
- ⚠️ İleride iOS istenirse: `nfc_transport` paketi zaten soyutlama
  sağlıyor. `NfcSessionService`'in iOS uygulaması yazılır, desteklenmeyen
  işlemler `TagNotSupported` döndürür. Feature katmanı değişmez.

## Reddedilen seçenekler

- **Baştan iOS eşitliği:** Özellik setini en zayıf platforma indirirdi.
- **iOS'u kısıtlı sürümle ekleme:** v1 kapsamını iki katına çıkarırdı.
