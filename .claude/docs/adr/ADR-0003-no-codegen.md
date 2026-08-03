# ADR-0003 — Kod üretimi (codegen) kullanılmayacak

**Durum:** Kabul edildi · 2026-08-03

## Bağlam

Tipik Flutter projesi `freezed` + `json_serializable` + `riverpod_generator`
kullanır. 13 paketli bir workspace'te bu şu anlama gelir:

- Her paket değişikliğinde `dart run build_runner build` beklemek
- 5 paralel terminalin aynı anda build_runner çalıştırması → kilit çakışması
- `.g.dart` / `.freezed.dart` dosyalarının git'te sürekli çakışması
- Yeni katılan birinin "kod neden derlenmiyor" ile yarım saat kaybetmesi

Dart 3'ün `sealed class`, `final class`, pattern matching ve
`switch` ifadeleri, freezed'in sağladığı değerin büyük kısmını dilin
kendisinde veriyor.

## Karar

Kod üretimi yok. Bunun yerine:

| İhtiyaç | Çözüm |
|---|---|
| Union / sealed tipler | Dart 3 `sealed class` + `switch` pattern matching |
| Değişmezlik | `final class` + `const` kurucu + elle `copyWith` |
| Eşitlik | Elle `==` / `hashCode` (`Object.hash` ile) |
| JSON | Elle `toJson()` / `fromJson()` |
| Riverpod provider | Elle `NotifierProvider(...)` |

## Sonuçlar

- ✅ `flutter analyze` ve `flutter test` doğrudan çalışır, ön adım yok.
- ✅ Paralel terminaller birbirini engellemez.
- ✅ Üretilen kodun ne olduğu görünür — hata ayıklamak kolay.
- ⚠️ `copyWith` / `==` elle yazılır. Kabul edilen maliyet.
- ⚠️ Büyük JSON modellerinde daha fazla yazım. `storage` paketinde
  model sayısı azdır, sorun değil.

## Yeniden değerlendirme koşulu

Elle yazılan `toJson`/`fromJson` sayısı 20'yi aşarsa bu karar
yeniden gözden geçirilir.
