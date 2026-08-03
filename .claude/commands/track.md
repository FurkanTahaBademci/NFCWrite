---
description: Bir iş koluna (track) gir ve sıradaki görevden devam et
argument-hint: T1 | T2 | T3 | T4 | T5
---

Sen artık **$ARGUMENTS** iş kolunda çalışıyorsun.

Aşağıdaki adımları sırayla uygula:

1. `.claude/README.md` dosyasını oku — süreç kuralları.
2. `.claude/docs/01-architecture.md` dosyasını oku — bağımlılık kuralları.
3. `.claude/docs/06-parallel-workflow.md` içindeki **dosya sahipliği
   tablosundan** $ARGUMENTS satırını bul. **Yalnızca o yollara yazacaksın.**
4. `.claude/tracks/` altında $ARGUMENTS ile başlayan dosyayı oku — görev listen.
5. `.claude/state/progress.md` dosyasını oku — "Engeller", "Devir notları" ve
   "Bekleyen sözleşme değişiklikleri" bölümlerine özellikle bak.
6. Track dosyanda **belirtilen okuma listesindeki** dokümanları oku.

Sonra:

- Track dosyandaki ilk `[ ]` görevi seç. Görev listesi sıralıdır — sıradan
  sapma, sonrakiler öncekilere bağımlı olabilir.
- Görevi `[~]` yap, işi yap, bitince `[x]` yap.
- Bir görev bitince `flutter analyze` çalıştır. Hata varsa devam etme, düzelt.
- `.claude/state/progress.md` içine tek satır kayıt ekle ve üstteki
  "Genel durum" tablosunda kendi satırını güncelle.
- Sonra bir sonraki göreve geç. Kullanıcı durdurana kadar devam et.

**Sınırlar:**

- Sahipliğinde olmayan bir dosyayı **değiştirme**. Gerekiyorsa
  `progress.md` → "Engeller" bölümüne yaz ve o görevi atlayıp bir sonrakine geç.
- `nfc_core` içindeki sözleşmeleri T1 dışında **kimse** değiştiremez.
  Değişiklik gerekiyorsa "Bekleyen sözleşme değişiklikleri" listesine yaz.
- Emin olmadığın bir NFC komutu/byte değeri varsa **tahmin etme** —
  `progress.md` → "Doğrulanacak teknik noktalar" listesine ekle.

İlk olarak hangi görevi aldığını tek cümleyle söyle, sonra çalışmaya başla.
