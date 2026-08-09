# ADR-0006 — vCard çözücü adresi kalıcı bir sözleşmedir

**Durum:** Kabul edildi · 2026-08-07 · **güncellendi 2026-08-10 (geçiş yapıldı)**
**İlgili:** `packages/services/ndef_codec/lib/src/vcard_share_link.dart`,
`docs/v/index.html`, `nfckart/nfckart.github.io` deposu

> **2026-08-10 — Adres taşındı.** Aktif adres artık
> `https://nfckart.github.io/v/`. Eski adres kalıcı köprüde bırakıldı.
> Ayrıntı: aşağıdaki *"Geçiş — 2026-08-10"* bölümü. Bu bölümden önceki
> metin, geçiş öncesi durumu ve kararın gerekçesini kaydeder.

## Bağlam

iOS arka plan NFC okuması yalnızca URI kayıtlarını işler; `text/vcard` MIME
kayıtlarını sessizce yok sayar. İki platformu aynı kartta memnun etmek için
**record stacking** kullanıyoruz: karta önce vCard kaydı, ardından çözücü
sayfaya işaret eden bir URI kaydı yazılıyor.

Bu URI'nin tabanı bir sabit:

```
https://furkantahabademci.github.io/NFCWrite/v/#<base64url(vCard)>
```

Bu adres **fiziksel kartlara kalıcı olarak yazılıyor.** Kartlar
kullanıcıların cüzdanında, masasında, ürün ambalajında; geri toplanamaz,
yeniden yazılamaz.

Kodda zaten "bu adresi değiştirme" uyarısı var. **Asıl risk bu değil.**
Gerçek tehlike, kodda tek satır değişmeden, GitHub hesabı ve repo ayarları
tarafından tetiklenen dört işlemdir:

| # | İşlem | Sonuç |
|---|---|---|
| 1 | GitHub hesabının kapatılması veya kullanıcı adının değiştirilmesi | `furkantahabademci.github.io` ölür |
| 2 | Repo'nun private yapılması | GitHub Pages yayını durur |
| 3 | Repo adının `NFCWrite` dışına çevrilmesi | Yol kırılır |
| 4 | GitHub'ın Pages'i ücretsiz katmandan kaldırması | Kontrolümüz dışında |

Dördü de **sahadaki tüm kartları aynı anda ve geri dönüşsüz** kırar.

Not: bu bir ölçek sorunu **değildir.** Kişi verisi `#` fragment'ında taşınır
ve tarayıcı fragment'ı sunucuya göndermez; GitHub'ın gördüğü tek şey herkes
için aynı statik dosyadır. Sayfa 13,8 KB (gzip) ve tamamen self-contained
(dış font/script/görsel yok) → GitHub Pages'in 100 GB/ay yumuşak sınırıyla
teorik tavan ~7 milyon açılış/ay. Sunucu tarafında darboğaz yok; sorun tek
nokta arıza.

## Karar

**1. Adres, genel API sözleşmesi statüsündedir.**
`VCardShareLink.defaultBaseUrl` sıradan bir sabit değil, geriye dönük uyumluluk
taahhüdüdür. Değiştirilmesi breaking change'dir ve yalnızca aşağıdaki geçiş
protokolüyle yapılabilir.

**2. Yukarıdaki dört işlem yasaktır.**
Repo private yapılamaz, yeniden adlandırılamaz; hesap adı değiştirilemez.
Bunlardan biri zorunlu hale gelirse önce geçiş tamamlanmalıdır.

**3. Kalıcı çözüm kendi alan adıdır.** *(açık — henüz uygulanmadı)*
Kendi alan adı + CNAME kurulursa barındırma sağlayıcısı bizim sorunumuz olmaktan
çıkar: GitHub'dan çıkmak gerekse DNS başka yere çevrilir, kartlar çalışmaya
devam eder. 1., 2. ve 4. maddeler böylece tamamen ortadan kalkar.

**4. Geçiş yapılırsa geriye dönük uyumlu olmalıdır.**
Yeni adres yalnızca yeni kartlara yazılır; eski adres **kalıcı olarak** ayakta
kalır ve çözmeye devam eder. Eski adresi kapatan bir geçiş, geçiş değil kırılmadır.

## Zamanlama — bu kararın maliyeti zamanla artar

Adres değişikliğinin maliyeti, o ana kadar dağıtılmış kart sayısıyla doğru
orantılıdır ve **geri alınamaz biçimde büyür.**

- **2026-08-07 itibarıyla:** kartlar yalnızca 3-4 kişide. Geçişin maliyeti ≈ sıfır.
- Birkaç yüz kart sonrası: geçiş, eski adresi ömür boyu ayakta tutmayı gerektirir.
- Binlerce kart sonrası: `github.io` adresine fiilen kalıcı bağımlılık.

Yani 3. madde ertelenebilir bir iyileştirme değil, **penceresi kapanan** bir karardır.

## Sonuçlar

- ✅ Sunucu tarafında ölçek sınırı yok; kart başına saklanan veri yok.
- ✅ Gizlilik: kişi verisi hiçbir sunucuya ulaşmaz.
- ⚠️ Barındırma sağlayıcısına kalıcı ve tek noktalı bağımlılık — 3. madde
  uygulanana kadar sürer.
- ⚠️ Repo yönetimiyle ilgili sıradan görünen işlemler (yeniden adlandırma,
  private'a alma) artık **yıkıcı işlem** sınıfındadır.

## Kural

**Repo adı, hesap adı ve Pages yayın durumu üretim altyapısıdır.**
Bunlara dokunan bir değişiklik, ADR-0005'teki yıkıcı NFC işlemleriyle aynı
ciddiyette ele alınır: önce geçiş planı, sonra işlem.

---

## Geçiş — 2026-08-10

### Neden

Adres, sahibinin gerçek adını taşıyordu (`furkantahabademci.github.io`).
Karta dokunan herkes tarayıcının adres çubuğunda bunu görüyordu. Çözücü
sayfa, adı taşımayan ayrı bir hesaba (`nfckart`) taşındı.

Zamanlama bu ADR'nin *"Zamanlama"* bölümüne göre seçildi: kartlar hâlâ
3-4 kişideydi, yani geçişin maliyeti pratikte sıfırdı. Pencere kapanmadan
hareket edildi.

### Yapılan

| | Önce | Sonra |
|---|---|---|
| Aktif adres | `furkantahabademci.github.io/NFCWrite/v/` | **`nfckart.github.io/v/`** |
| Eski adres | çözücü | **köprü** — fragment'ı koruyarak yeni adrese yönlendirir |
| Barındırma | uygulama deposu (`docs/v/`) | ayrı depo (`nfckart/nfckart.github.io`) |

Depo adı bilerek `nfckart.github.io` seçildi: GitHub bu adı *user site*
olarak yayınlar ve yoldan repo adını düşürür. NDEF URI kaydında saklanan
bayt 39'dan 20'ye indi — kart başına 19 bayt kazanç.

### Madde 4'e uygunluk

Geçiş geriye dönük uyumludur: yeni adres yalnızca yeni kartlara yazılır,
eski adres kapatılmadı. Eski kartlar çalışmaya devam ediyor.

Yönlendirme **zorunlu olarak istemci tarafındadır.** Kişi verisi `#`
fragment'ında taşınır ve fragment tarayıcıdan sunucuya hiç gitmez; sunucu
tarafı bir 301 veriyi taşıyamazdı. GitHub Pages zaten statik sunucudur ve
yönlendirme kuralı desteklemez. Tek doğru biçim:
`location.replace(yeniAdres + location.hash)`.

### Kodda karşılığı

`VCardShareLink` artık **üretim** ile **tanımayı** ayırıyor:

- `defaultBaseUrl` — yeni kartlara yazılan tek adres.
- `legacyBaseUrls` — artık yazılmayan, ama çözülmesi gereken adresler.
- `isShareLink(url)` — tanıma **her zaman** buradan yapılır.

Bu ayrım şart, çünkü eski adres yalnızca sahadaki kartlarda değil
**diskte** de yaşıyor: `WriteDraftStore` yazma taslağını ve şablonları ham
NDEF yükü olarak saklıyor, dolayısıyla eski adresli bir URI kaydı uygulama
güncellemesinden sağ çıkıp geri yükleniyor. `startsWith(defaultBaseUrl)`
ile tanıma yapan kod bunu kaçırır ve düzenlenen vCard'ın bağlantısı bayat
kalır — kart, MIME kaydında yeni kişiyi, URI kaydında eski kişiyi taşır.

### Yasak işlemler artık iki hesabı birden kapsıyor

Bu ADR'nin *"Karar"* bölümündeki 2. madde (yeniden adlandırma, private'a
alma, hesap adı değişikliği, hesap silme) **her iki hesap için** geçerlidir:

| Hesap / depo | Neyi taşıyor | Düşerse |
|---|---|---|
| `nfckart/nfckart.github.io` | aktif çözücü | tüm yeni kartlar kırılır |
| `FurkanTahaBademci/NFCWrite` | eski adres köprüsü | tüm eski kartlar kırılır |

Geçiş, tek nokta arızayı **ikiye çıkardı** — bu, geçişin kabul edilen
bedelidir. Her iki hesapta da 2FA ve kurtarma kodları zorunludur.

### Madde 3 hâlâ açık

Kendi alan adı alınmadı. Yukarıdaki tablo tam olarak 3. maddenin çözdüğü
sorundur: CNAME kurulsaydı barındırma sağlayıcısı değiştirilebilir olurdu
ve hesap adı üretim altyapısı olmaktan çıkardı. Karar ertelendi; maliyeti
her yeni kartla büyümeye devam ediyor.
