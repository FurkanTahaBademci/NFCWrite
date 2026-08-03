# ADR-0004 — Hatalar `Result<T>` ile taşınır, exception ile değil

**Durum:** Kabul edildi · 2026-08-03

## Bağlam

NFC işlemlerinde "hata" normaldir, istisnai değildir:

- Kullanıcı etiketi erken çekti
- Etiket salt-okunur
- İçerik sığmadı
- Şifre yanlış

Bunları exception yapmak, her çağrının etrafına `try/catch` yazmayı
zorunlu kılar ve derleyici hangi hataların gelebileceğini söylemez.

## Karar

`nfc_core` içinde:

```dart
sealed class Result<T> { const Result(); }
final class Ok<T> extends Result<T> { final T value; }
final class Err<T> extends Result<T> { final NfcFailure failure; }
```

`NfcFailure` de `sealed` — böylece `switch` üzerinde **exhaustive** kontrol
yapılır. Yeni bir hata tipi eklendiğinde onu ele almayan her `switch`
derleme hatası verir.

Gerçekten istisnai durumlar (programlama hatası, geçersiz argüman) hâlâ
`throw` edilir.

## Sonuçlar

- ✅ Hata yolları derleyici tarafından zorlanır, unutulamaz.
- ✅ `nfc_core` Flutter'a bağımlı olmadan hata modelini taşır.
- ✅ Kullanıcı mesajı `localization` katmanında üretilir → i18n doğal.
- ⚠️ `async` zincirlerde `Result` yaymak biraz tekrar üretir.
  `Result.map` / `flatMap` yardımcıları bunu azaltır.

## Kullanım

```dart
final result = await ops.setPassword(pwd);
switch (result) {
  case Ok():                       showSuccess();
  case Err(failure: TagLost()):    showRetry();
  case Err(:final failure):        showError(l10n.messageFor(failure));
}
```
