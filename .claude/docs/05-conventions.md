# 05 — Kod Standartları

## Paket iç düzeni

Her paket aynı şekilde kurulur:

```
packages/<grup>/<paket_adi>/
├── lib/
│   ├── <paket_adi>.dart        ← TEK public API (barrel). Sadece export satırları.
│   └── src/                    ← Dışarıdan import edilemez
│       ├── ...
├── test/
├── analysis_options.yaml       ← kök dosyayı include eder
└── pubspec.yaml
```

Feature paketlerinde `src/` altı:

```
src/
├── application/     Riverpod controller'ları, state sınıfları
├── domain/          Yalnızca bu özelliğe ait modeller
├── presentation/
│   ├── pages/       Tam ekranlar
│   └── widgets/     Bu özelliğe özel widget'lar
└── routes.dart      GoRoute listesi
```

## İsimlendirme

| Şey | Kural | Örnek |
|---|---|---|
| Dosya | `snake_case.dart` | `write_record_page.dart` |
| Sınıf | `PascalCase` | `NtagPasswordConfig` |
| Sabit | `lowerCamelCase` | `defaultMifareKeys` |
| Riverpod provider | `<ad>Provider` | `tagOperationsProvider` |
| Controller | `<Ad>Controller` | `WriteSessionController` |
| Arayüz (soyut) | Ön ek yok, `I` kullanma | `TagOperations` ✅ `ITagOperations` ❌ |
| Uygulama (somut) | `<Arayüz>Impl` | `TagOperationsImpl` |
| NFC komut sabitleri | `SCREAMING_SNAKE` yok, `cmdXxx` | `cmdFastRead` |

## Hata yönetimi

**Kural: Beklenen hata `Result`, beklenmeyen hata `throw`.**

```dart
// ✅ Doğru — etiket kayboldu, kullanıcı hatası, şifre yanlış → Result
Future<Result<TagMemory>> readMemory() async {
  final res = await _transport.transceive(...);
  return switch (res) {
    Ok(:final value) => Ok(TagMemory.parse(value)),
    Err(:final failure) => Err(failure),
  };
}

// ✅ Doğru — programlama hatası → assert / throw
void writePage(int page, Uint8List data) {
  if (data.length != 4) {
    throw ArgumentError.value(data, 'data', 'Sayfa verisi tam 4 byte olmalı');
  }
}
```

`NfcFailure` alt tipleri (nfc_core):

```
NfcFailure
├── NfcUnavailable          NFC yok / kapalı
├── TagLost                 Etiket çekildi
├── TagNotSupported         Bu işlem bu etiket tipinde yok
├── TagReadOnly             Yazma korumalı
├── InsufficientSpace       İçerik sığmıyor (needed, available)
├── AuthenticationRequired  Şifre gerekli
├── AuthenticationFailed    Şifre yanlış (kalanDeneme?)
├── InvalidArgument         Geçersiz parametre
├── OperationCancelled      Kullanıcı iptal etti
├── Timeout                 Zaman aşımı
└── TransportError          Alt katman hatası (mesaj + orijinal hata)
```

Kullanıcıya gösterilecek metin `nfc_core` içinde **yoktur**.
`localization/lib/src/failure_messages.dart` çeviriyi yapar.

## Riverpod kullanımı (v3)

- `StateNotifier` **kullanma** — `Notifier` / `AsyncNotifier` kullan.
- Kod üretimi (riverpod_generator) **kullanma** — elle `NotifierProvider`.
- Servis provider'ları `nfc_core` içinde **tanımlanmaz**; her feature kendi
  ihtiyacı olan provider'ı `UnimplementedError` fırlatan bir yer tutucuyla
  ilan eder, composition root `override` ile gerçeğini bağlar:

```dart
// feature_tools/lib/src/application/providers.dart
final tagOperationsProvider = Provider<TagOperations>(
  (ref) => throw UnimplementedError(
    'apps/nfc_toolkit composition root içinde override edilmeli',
  ),
);
```

```dart
// apps/nfc_toolkit/lib/src/di/providers.dart
ProviderScope(
  overrides: [
    tagOperationsProvider.overrideWithValue(TagOperationsImpl(transport)),
  ],
  child: const NfcToolkitApp(),
)
```

Bu, feature'ların `tag_ops` paketini görmeden çalışmasını sağlayan mekanizmadır.

## Byte / hex işleri

Elle `int.parse(x, radix: 16)` yazma. `shared_utils` kullan:

```dart
hexToBytes('04A2FF00')        → Uint8List
bytesToHex(bytes)             → '04A2FF00'
bytesToHex(bytes, separator: ' ')  → '04 A2 FF 00'
bytes.getBit(3)               → bool
byte.setBits(offset: 4, width: 2, value: 3)
```

## Test

| Katman | Test tipi | Beklenti |
|---|---|---|
| `nfc_core`, `shared_utils`, `ndef_codec`, `tag_ops` | Saf birim testi | **Zorunlu**, kapsam > %70 |
| `storage` | sqflite_common_ffi ile entegrasyon | Zorunlu |
| `nfc_transport` | Sahte (fake) platform | En az mutlu yol |
| `feature_*` | Widget testi + controller testi | Kritik akışlar |

`tag_ops` testleri **sahte transport** ile yazılır — beklenen komut byte
dizisi verilir, cevap sahte döndürülür. Gerçek etiket gerekmez:

```dart
final transport = FakeTransport()
  ..expect(hexToBytes('60'), respondsWith: hexToBytes('0004040201000F03'));
final ops = TagOperationsImpl(transport);
expect(await ops.identify(), isA<Ok<TagIdentity>>());
```

## Yorum dili

Kod yorumları **Türkçe**. Public API dokümantasyonu (`///`) Türkçe.
Değişken/sınıf adları **İngilizce**.

Yorum "ne yaptığını" değil "neden öyle yaptığını" anlatır:

```dart
// ❌ AUTH0'ı 0xFF yap
// ✅ AUTH0 en son yazılır; önce yazılırsa PWD sayfası anında korumaya
//    girer ve parolayı yazamadan etiket kilitlenir. Bkz. 03-nfc-reference §2.8
```

## Commit mesajları

```
<tip>(<paket>): <özet>

feat(tag_ops): NTAG şifre koyma akışı
fix(ndef_codec): URI ön ek 0x0D yanlış eşleşiyordu
docs(claude): T4 görev listesi güncellendi
refactor(feature_read): dump görüntüleyici design_system'e taşındı
test(shared_utils): hex dönüşüm kenar durumları
chore(deps): nfc_manager 4.2.1
```
