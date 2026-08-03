---
description: Tüm track'lerin ilerleme durumunu özetle
---

Projenin güncel durumunu çıkar:

1. `.claude/state/progress.md` oku.
2. `.claude/tracks/*.md` dosyalarının **hepsini** oku.
3. Her track için `[x]`, `[~]`, `[ ]` görev sayılarını say.
4. `.claude/docs/02-feature-matrix.md` üzerinden toplam özellik tamamlanma
   yüzdesini hesapla.
5. `git log --oneline -15` ve `git status --short` çalıştır.

Şu biçimde raporla:

```
TRACK      AŞAMA          BİTEN/TOPLAM   %     SON İŞ
T1 Core    Aşama 2        12/24          50%   ...
...

GENEL: %XX  (özellik matrisi: X/Y)

ENGELLER
- ...

BEKLEYEN SÖZLEŞME DEĞİŞİKLİKLERİ
- ...

ÖNERİLEN SONRAKİ ADIM
- Hangi track kritik yolda, kim kimi bekliyor
```

Rapor kısa olsun. Dosya içeriklerini kopyalama, sadece sayıları ve sonucu ver.
