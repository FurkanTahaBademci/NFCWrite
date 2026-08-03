# Şablon — Yeni etiket aracı ekleme (T4)

## 1. Risk seviyesini belirle

| Seviye | Tanım | Gereken |
|---|---|---|
| `safe` | Etiketi değiştirmez (okuma) | — |
| `content` | NDEF içeriğini değiştirir, geri yazılabilir | `DangerAck` + onay |
| `config` | Yapılandırma byte'larını değiştirir | `DangerAck` + onay + yedek |
| `irreversible` | **Geri alınamaz** (kilit, CFGLCK, AUTHLIM) | Yukarıdakiler + uzman modu |

## 2. Sözleşme (T1 onayı gerekir)

`nfc_core/lib/src/contracts/tag_operations.dart` içine imza ekle:

```dart
/// <Ne yaptığı, tek cümle>
///
/// [ack] geri alınamaz işlem onayı. Bkz. ADR-0005.
Future<Result<void>> setPassword({
  required Uint8List password,
  required Uint8List pack,
  required int startPage,
  required DangerAck ack,
});
```

`safe` seviyesindeki araçlarda `DangerAck` **yoktur**.

## 3. Uygulama (`tag_ops/lib/src/operations/`)

Uyulacak sıra:

```dart
Future<Result<void>> setPassword({...}) async {
  // 1. Uygunluk: bu etiket bu işlemi destekliyor mu?
  final id = await identify();
  if (id is! Ok || !id.value.supportsPassword) {
    return const Err(TagNotSupported());
  }

  // 2. Sınır kontrolü — UI'ya güvenme
  if (password.length != 4) return const Err(InvalidArgument());

  // 3. Yedek (config/irreversible seviyesinde zorunlu)
  final backup = await readMemory();

  // 4. İşlemi yap — sıra kritikse gerekçesini yorumla yaz
  //    docs/03-nfc-reference.md §2.8: AUTH0 EN SON yazılır.

  // 5. Doğrula — geri oku, eşleşmiyorsa Err döndür
}
```

## 4. Test (`tag_ops/test/`)

`FakeTransport` ile **gönderilen byte dizisini birebir** doğrula:

```dart
test('şifre koyma doğru sırayla yazar', () async {
  final t = FakeTransport();
  await ops.setPassword(...);
  expect(t.sentCommands, [
    hexToBytes('A22B11223344'),   // PWD
    hexToBytes('A22C55660000'),   // PACK
    hexToBytes('A22A80000000'),   // CFG1 (PROT)
    hexToBytes('A2290000 04'),    // CFG0 (AUTH0) — EN SON
  ]);
});
```

Sıra yanlış olursa test kırmızı olmalı. Bu testin amacı budur.

## 5. Arayüz (`feature_tools/lib/src/presentation/pages/tools/`)

Ortak `ToolScaffold` kullan:

```dart
ToolScaffold(
  toolId: 'set_password',
  risk: ToolRisk.config,
  description: l10n.setPasswordDescription,
  warning: l10n.setPasswordWarning,       // ne ters gidebilir
  parameters: [ /* form */ ],
  onExecute: (ack) => controller.run(ack),
)
```

## 6. Kayıt

- [ ] `ToolCatalog` içine ekle (id, ikon, kategori, risk, hangi etiket tipleri)
- [ ] `localization` → TR + EN ad, açıklama, uyarı metni (T5'e haber ver)
- [ ] `.claude/docs/02-feature-matrix.md` → C bölümüne satır ekle / işaretle
- [ ] Gerçek etikette test et, sonucu `state/progress.md` içine yaz
