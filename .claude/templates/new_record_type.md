# Şablon — Yeni NDEF kayıt tipi ekleme (T3)

Her yeni kayıt tipi bu 6 parçadan oluşur. Hiçbirini atlama.

## 1. İçerik modeli (`ndef_codec/lib/src/content/`)

`NdefContent` sealed hiyerarşisine yeni bir `final class` ekle:

```dart
final class WifiContent extends NdefContent {
  const WifiContent({
    required this.ssid,
    required this.authType,
    required this.encryption,
    this.password,
    this.hidden = false,
  });

  final String ssid;
  final WifiAuthType authType;
  final WifiEncryption encryption;
  final String? password;
  final bool hidden;

  @override
  bool operator ==(Object other) => /* elle */;
  @override
  int get hashCode => Object.hash(ssid, authType, encryption, password, hidden);
}
```

> `NdefContent` sealed olduğu için, yeni tip eklendiğinde onu ele almayan her
> `switch` derleme hatası verir. Bu istenen davranıştır — kırılan yerleri
> tek tek doldur.

## 2. Kodlayıcı (`ndef_codec/lib/src/encoders/`)

```dart
NdefRecordEntity encodeWifi(WifiContent c) { ... }
```

## 3. Çözücü (`ndef_codec/lib/src/decoders/`)

```dart
WifiContent? decodeWifi(NdefRecordEntity r) { ... }  // uymuyorsa null
```

`NdefDecoder.decode()` içindeki tip tespit zincirine ekle.

## 4. Çift yönlü test (`ndef_codec/test/`)

```dart
test('WiFi kaydı çift yönlü', () {
  const content = WifiContent(ssid: 'EvAgi', authType: ..., password: '12345678');
  expect(decodeWifi(encodeWifi(content)), content);
});

test('WiFi kaydı bilinen byte dizisiyle eşleşiyor', () {
  // Gerçek etiketten alınmış altın örnek
  expect(bytesToHex(encodeWifi(content).payload), '10 0E 00 36 ...');
});
```

**Altın örnek olmadan kabul edilmez.** Gerçek bir etiketten okunmuş ya da
NFC Tools ile yazılmış bir örnekle karşılaştır.

## 5. Sihirbaz ekranı (`feature_write/lib/src/presentation/pages/wizards/`)

- Form alanları + doğrulama
- Canlı boyut göstergesi (kaç byte tutacak)
- Canlı önizleme

## 6. Kayıt

- [ ] `RecordTypeCatalog` içine ekle (ikon, ad, kategori, açıklama)
- [ ] `localization` → TR + EN ad/açıklama (T5'e haber ver)
- [ ] `.claude/docs/02-feature-matrix.md` → B bölümüne satır ekle / işaretle
- [ ] T2'ye haber ver — okuma tarafında zengin gösterim ekleyecek
