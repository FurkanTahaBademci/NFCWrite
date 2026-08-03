# 04 — Arayüz ve Akış Tasarımı

## Navigasyon iskeleti

Alt gezinme çubuğu (bottom navigation), 4 sekme + ayarlar:

```
┌─────────────────────────────────────────┐
│  NFC Toolkit                      ⚙️     │  ← AppBar (ayarlara gider)
├─────────────────────────────────────────┤
│                                         │
│              [sekme içeriği]            │
│                                         │
├─────────────────────────────────────────┤
│   📖 Oku   ✏️ Yaz   🛠 Diğer   🕘 Geçmiş  │
└─────────────────────────────────────────┘
```

Rota tanımları (go_router, her feature kendi rotalarını ihraç eder):

```
/read                       Okuma sekmesi
/read/detail/:id            Okuma sonucu detayı
/read/dump                  Ham bellek görüntüleyici
/write                      Kayıt listesi
/write/add                  Kayıt tipi seçici
/write/add/:type            Kayıt tipi sihirbazı
/tools                      Araç ızgarası
/tools/:toolId              Tekil araç ekranı
/history                    Geçmiş listesi
/history/:id                Geçmiş detayı
/settings                   Ayarlar
/settings/about             Hakkında
```

## Merkezî tarama arayüzü (NfcScanSheet)

Uygulamadaki **her** NFC işlemi aynı alt sayfayı (bottom sheet) kullanır.
Bu bileşen `design_system` içindedir ve tek sorumluluğu vardır: durum göster.

```
      ┌───────────────────────────┐
      │            ⌒              │
      │        ((  📡  ))         │   ← nabız animasyonu
      │            ⌄              │
      │                           │
      │   Etiketi telefonun       │
      │   arkasına yaklaştırın    │
      │                           │
      │   [ İptal ]               │
      └───────────────────────────┘
```

Durumlar: `idle` → `scanning` → `tagFound` → `working(ilerleme %)` →
`success` / `failure`. Her durumun kendi rengi, ikonu ve haptik geri
bildirimi vardır.

## Tehlikeli işlem onay akışı (DangerDialog)

Geri alınamaz her işlem bu akıştan geçer:

```
1. Ne olacağını düz Türkçe anlat
2. "Bu işlem GERİ ALINAMAZ" kırmızı rozet
3. Etkilenecek etiket bilgisini göster (UID)
4. Otomatik yedek onayı: "Önce yedek al" (varsayılan açık)
5. Kaydırarak onayla (slider) — kazara dokunmayı engeller
```

Uzman modu açıksa 5. adım tek dokunuşa iner, ama 1–4 kalır.

## Ekran ekran içerik

### Oku sekmesi
- Boşken: büyük tarama düğmesi + son 3 okuma kısayolu
- Okuduktan sonra sekmeli detay: **Bilgi** · **NDEF** · **Bellek** · **Teknik**
- Her satır uzun basınca kopyalanır

### Yaz sekmesi
- Üstte kapasite çubuğu: `128 / 144 byte` — dolunca kırmızı
- Kayıt kartları listesi, sürükle-bırak sıralama, kaydırarak silme
- Altta sabit "Yaz" düğmesi + "Yazdıktan sonra kilitle" anahtarı
- `+` → kategorili kayıt tipi seçici (arama kutulu)

### Diğer sekmesi
Araçlar risk seviyesine göre gruplanmış ızgara:

```
GÜVENLİ          Bilgi al · Bellek dökümü · Sayaç oku · İmza doğrula
İÇERİK           Kopyala · Temizle · Şablon yaz
YAPILANDIRMA     Biçimlendir · Şifre koy · Şifre kaldır · Mirror · Sayaç
GERİ ALINAMAZ    Salt-okunur yap · Sayfa kilitle · CFGLCK   [uzman modu]
```

Her araç kartında: ikon, ad, tek satır açıklama, risk rozeti.

### Geçmiş sekmesi
- Zaman gruplu liste (Bugün / Dün / Bu hafta)
- Her satır: tip ikonu, takma ad ya da UID, içerik özeti, saat
- Kaydırarak sil, uzun basarak çoklu seçim

## Tasarım dili

| Token | Değer |
|---|---|
| Tema | Material 3, dinamik renk (Android 12+), yedek tohum `#2563EB` |
| Yarıçap | Kart 16, düğme 12, alt sayfa 28 |
| Boşluk | 4'ün katları: 4, 8, 12, 16, 24, 32 |
| Tipografi | Sistem yazı tipi; hex/dump alanları monospace |
| Risk renkleri | Güvenli `#16A34A` · Dikkat `#F59E0B` · Tehlike `#DC2626` |

## Geri bildirim

| Olay | Haptik | Ses |
|---|---|---|
| Etiket bulundu | `mediumImpact` | kısa bip (ayardan kapatılabilir) |
| İşlem başarılı | `lightImpact` | onay tonu |
| İşlem başarısız | `heavyImpact` | hata tonu |
| Tehlikeli onay | `selectionClick` | — |

## Erişilebilirlik

- Tüm dokunma hedefleri ≥ 48×48 dp
- Hex dökümü ekran okuyucuya byte byte değil, "sayfa 4: 01 02 03 04" olarak okunur
- Renk tek başına anlam taşımaz — risk seviyesi ikon + metinle de belirtilir
- Metin ölçeklendirme 200%'e kadar bozulmadan çalışır
