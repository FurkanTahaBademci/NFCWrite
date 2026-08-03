# ADR-0002 — Micro-package monorepo (Dart pub workspace)

**Durum:** Kabul edildi · 2026-08-03

## Bağlam

İstek: "microservice mimarisine, ölçeklenebilir". 5 kişi/terminal paralel
çalışacak. Tek `lib/` klasörlü klasik Flutter yapısında bu şu sorunları
doğurur:

- Aynı dosyalarda sürekli git çakışması
- Katman sınırlarını yalnızca disiplin korur, derleyici zorlamaz
- Bir özelliğin testi tüm uygulamayı ayağa kaldırmayı gerektirir

## Karar

Her modül ayrı bir Dart paketi. Dart 3.6+ **pub workspace** ile tek
`pubspec.lock` ve tek `.dart_tool` altında çözülür.

Melos **kullanılmıyor** — pub workspace aynı işi SDK yerleşiği olarak yapıyor,
ek araç bağımlılığı gereksiz.

## Sonuçlar

- ✅ Katman ihlali **derleme hatası** olur: `feature_read`, `tag_ops`'u
  `pubspec.yaml`'ında listelemediği için import edemez.
- ✅ `flutter test packages/services/tag_ops` saniyeler sürer, UI gerekmez.
- ✅ Her track kendi paketinde çalışır → çakışma yok.
- ✅ Yeni özellik = yeni paket, mevcut kod değişmez.
- ⚠️ Yeni paket eklerken kök `pubspec.yaml` `workspace:` listesi güncellenmeli.
- ⚠️ IDE'ler workspace'i doğru göstermek için güncel Dart eklentisi ister.

## Ölçüt

Bir özelliğin kaldırılması, `pubspec.yaml`'dan tek satır silmekle mümkün
olmalı. Değilse bağımlılık sızıntısı var demektir.
