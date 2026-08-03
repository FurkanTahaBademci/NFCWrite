# 00 — Vizyon ve Kapsam

## Hedef

Piyasadaki NFC araç uygulamalarının **ücretli sürümlerinde bile bulunan** tüm
işlevleri tek bir uygulamada, ücretsiz ve daha iyi bir arayüzle sunmak.

Referans aldığımız uygulamalar ve onlarda gördüğümüz yetenekler:

| Uygulama | Öne çıkan yetenekler |
|---|---|
| NFC Tools / NFC Tools PRO (wakdev) | Okuma, yazma, 20+ kayıt tipi, kopyalama, kilitleme, şifre, biçimlendirme, sayaç, mirror, ham komut |
| TagWriter (NXP) | NDEF kayıt sihirbazları, çoklu etiket yazma, koruma |
| NFC TagInfo (NXP) | Derin teknik analiz, bellek dökümü, imza doğrulama |
| MIFARE Classic Tool | Sektör/blok dökümü, anahtar sözlüğü, dump düzenleme |

**Kapsamımız = bu dördünün birleşimi.**

## Ücretsiz vereceğimiz "PRO" özellikler

Rakiplerde para duvarının arkasında olan, bizde açık olacak işlevler:

- Etiket kopyalama (kaynak → hedef klonlama)
- NTAG21x şifre koyma / kaldırma (PWD + PACK + AUTH0 + PROT)
- Kalıcı salt-okunur yapma (statik + dinamik lock bytes)
- Tam bellek dökümü (dump) ve dosyaya kaydetme / geri yükleme
- Ham APDU / komut konsolu (transceive)
- UID mirror ve NFC sayaç (counter) yapılandırması
- ECC orijinallik imzası okuma (READ_SIG)
- Çoklu yazma modu (bir mesajı arka arkaya N etikete yazma)
- Toplu görev zincirleri (otomasyon)

## Kapsam DIŞI (şimdilik)

Bunlar bilinçli olarak yapılmıyor — sorulursa cevap bu:

| Konu | Neden |
|---|---|
| iOS desteği | ADR-0001: Android'e odaklanma kararı. CoreNFC düşük seviye komutları kısıtlıyor. |
| MIFARE Classic anahtar kırma (nested/darkside saldırıları) | Telefon NFC yongası bu saldırılar için gereken zamanlama kontrolünü vermez. Sadece bilinen anahtar sözlüğü denenir. |
| Banka kartı / EMV verisi okuma | Yasal ve etik risk. Yapılmayacak. |
| Kart emülasyonu (HCE) | Ayrı ürün kapsamı. v2 değerlendirmesi. |
| Erişim kartı klonlama (kurumsal kimlik kartları) | Yalnızca kullanıcının kendi etiketleri hedeflenir. |

## Güvenlik duruşu

Bu uygulama **kullanıcının kendi etiketleri üzerinde** çalışmak için tasarlandı.
Geri alınamaz her işlem (kilitleme, şifre, biçimlendirme) için:

1. Ne olacağı açıkça yazılır ("Bu işlem GERİ ALINAMAZ").
2. Kullanıcı onay diyaloğunda işlemi yazarak/kaydırarak teyit eder.
3. İşlem öncesi otomatik yedek (dump) alınır ve geçmişe yazılır.

## Başarı ölçütü (v1.0)

- [ ] NTAG213/215/216 üzerinde tüm işlevler doğrulandı
- [ ] MIFARE Ultralight / Ultralight C okuma + yazma
- [ ] MIFARE Classic 1K/4K sektör dökümü (bilinen anahtarlarla)
- [ ] ISO15693 (ICODE SLIX) okuma + yazma
- [ ] 25+ NDEF kayıt tipi oluşturulabiliyor
- [ ] Tüm ekranlar TR + EN
- [ ] `flutter analyze` sıfır uyarı
- [ ] Çekirdek paketlerde birim test kapsamı > %70
