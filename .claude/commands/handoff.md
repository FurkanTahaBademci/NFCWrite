---
description: Oturumu kapat - ilerlemeyi kaydet ve devir notu bırak
---

Bu oturumda yaptığın işi kapat. Sırayla:

1. `flutter analyze` çalıştır. Hata varsa **önce düzelt**, yarım bırakma.
2. `flutter test` çalıştır. Kırık test varsa düzelt ya da neden kırık
   olduğunu devir notuna yaz.
3. Kendi track dosyanda (`.claude/tracks/T<N>-*.md`) bu oturumda bitirdiğin
   görevleri `[x]`, yarım kalanı `[~]` olarak işaretle.
4. `.claude/state/progress.md` içinde:
   - "Genel durum" tablosunda kendi satırını güncelle
   - "Kayıt" bölümüne bu oturumun satırlarını ekle (en üste)
   - Başka bir track'i etkileyen bir şey yaptıysan → "Devir notları"
   - Beklediğin bir şey varsa → "Engeller"
   - `nfc_core` değişikliği gerekiyorsa → "Bekleyen sözleşme değişiklikleri"
   - Emin olamadığın bir NFC değeri varsa → "Doğrulanacak teknik noktalar"
5. `git status --short` ile değişen dosyaları göster.
6. Uygun bir commit mesajı **öner** (`docs/05-conventions.md` biçiminde).
   Kullanıcı onaylamadan commit **atma**.

Son olarak 5 satırı geçmeyen bir özet ver:
- Ne bitti
- Ne yarım kaldı ve nerede duruyor
- Bir sonraki oturumda ilk yapılacak iş
