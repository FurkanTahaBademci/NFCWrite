# NFC Toolkit — Claude Yönergesi

> **DUR VE OKU.** Bu depoda herhangi bir işe başlamadan önce
> **`.claude/README.md`** dosyasını oku. Tüm süreç, mimari kuralları, görev
> panosu ve track (iş kolu) tanımları oradan yürütülür.

## Zorunlu okuma sırası

Bir göreve başlarken şu sırayla oku (her seferinde, hafızandan varsayma):

1. `.claude/README.md` — komuta merkezi, süreç kuralları
2. `.claude/docs/01-architecture.md` — mimari sınırlar ve bağımlılık kuralları
3. `.claude/tracks/T<N>-*.md` — üzerinde çalıştığın track'in görev listesi
4. `.claude/state/progress.md` — güncel durum, kim ne yapıyor

## Bu proje nedir?

Android için gelişmiş bir NFC aracı (NFC Tools benzeri, ancak ücretli sürüm
özellikleri dahil): okuma, yazma, kopyalama, kilitleme, biçimlendirme,
şifre koyma/kaldırma, bellek dökümü, ham komut konsolu.

- **Platform:** yalnızca Android (bkz. `.claude/docs/adr/ADR-0001-platform.md`)
- **Mimari:** micro-package monorepo, Dart pub workspace
- **State:** Riverpod 3
- **NFC:** `nfc_manager` 4.x, `nfc_transport` paketiyle sarmalanmış

## Değişmez kurallar (ihlal = PR reddi)

1. **Katman sınırı:** `packages/features/*` asla `nfc_transport`, `tag_ops`
   veya `storage` paketlerini import etmez. Sadece `nfc_core` sözleşmelerini
   kullanır. Somut uygulamalar yalnızca `apps/nfc_toolkit` (composition root)
   içinde bağlanır.
2. **`src/` gizlidir:** Bir paketin dışından `package:x/src/...` import edilmez.
   Her paket `lib/<paket_adi>.dart` barrel dosyasından API açar.
3. **Kod üretimi (codegen) yok:** freezed/build_runner kullanılmaz.
   Gerekçe: `.claude/docs/adr/ADR-0003-no-codegen.md`
4. **Yıkıcı NFC işlemi = çift onay:** Kilitleme, şifre koyma, biçimlendirme
   gibi geri alınamaz işlemler onay diyaloğu olmadan çalıştırılmaz.
5. **Track sınırı:** Kendi track'inin sahip olmadığı dosyayı değiştirme.
   Sahiplik tablosu: `.claude/docs/06-parallel-workflow.md`

## Sık kullanılan komutlar

```bash
flutter pub get                        # workspace kökünden, tüm paketler
flutter analyze                        # workspace kökünden, tüm paketler
flutter test                           # workspace kökünden, tüm paketler
cd apps/nfc_toolkit && flutter run     # cihazda çalıştır (gerçek cihaz şart)
```

NFC test edilebilir bir emülatör yoktur — **fiziksel Android cihaz zorunludur.**
