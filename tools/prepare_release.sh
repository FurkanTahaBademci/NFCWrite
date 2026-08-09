#!/usr/bin/env bash
# Yayin manifestini (releases/version.json) gercek APK'dan uretir.
#
# Neden betik: manifest, guncelleme kanalinin tetigidir. UpdateService onu
# raw.githubusercontent.com/main uzerinden ceker, buildNumber'i karsilastirir,
# APK'yi indirir ve **sha256 tutmazsa kurulumu reddeder.** Yer tutucu ya da
# bayat bir hash, tum kullanicilara kirik guncelleme gosterir.
#
# Betik ayrica APK'nin debug anahtariyla imzalanmadigini dogrular:
# android/key.properties yoksa Gradle sessizce debug anahtarina duser
# (bkz. android/app/build.gradle.kts) ve o APK dagitilamaz. Bu hata
# v0.1.6'da bir kez yasandi (commit 0e3a735).
#
# Kullanim:
#   tools/prepare_release.sh <apk-yolu>

set -euo pipefail

APK="${1:-}"
if [[ -z "$APK" || ! -f "$APK" ]]; then
  echo "kullanim: $0 <apk-yolu>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/releases/version.json"

VERSION="$(sed -n 's/^version: \([0-9.]*\)+\([0-9]*\)$/\1/p' "$ROOT/apps/nfc_toolkit/pubspec.yaml")"
BUILD="$(sed -n 's/^version: \([0-9.]*\)+\([0-9]*\)$/\2/p' "$ROOT/apps/nfc_toolkit/pubspec.yaml")"
if [[ -z "$VERSION" || -z "$BUILD" ]]; then
  echo "HATA: pubspec.yaml'dan surum okunamadi." >&2
  exit 1
fi

echo "surum      : $VERSION+$BUILD  (pubspec.yaml'dan)"
echo "apk        : $APK"

# --- 1. Imza kontrolu: debug anahtariyla imzalanmis APK yayinlanamaz -------
echo
echo "--- imza ---"
if command -v apksigner >/dev/null 2>&1; then
  CERTS="$(apksigner verify --print-certs "$APK" 2>/dev/null || true)"
  if [[ -z "$CERTS" ]]; then
    echo "HATA: apksigner APK'yi dogrulayamadi." >&2
    exit 1
  fi
  echo "$CERTS" | grep -i "Subject\|DN:" || true
  if echo "$CERTS" | grep -qi "Android Debug"; then
    echo >&2
    echo "DUR. APK debug anahtariyla imzalanmis — DAGITILAMAZ." >&2
    echo "android/key.properties eksik olabilir; olmadan Gradle sessizce" >&2
    echo "debug anahtarina duser. Once onu koy, sonra yeniden build al." >&2
    exit 1
  fi
  echo "✓ debug anahtari degil"
else
  echo "UYARI: apksigner bulunamadi — imza DOGRULANAMADI." >&2
  echo "Yayinlamadan once elle kontrol et:" >&2
  echo "  apksigner verify --print-certs $APK" >&2
fi

# --- 2. versionCode APK ile pubspec ayni mi -------------------------------
echo
echo "--- versionCode ---"
if command -v aapt2 >/dev/null 2>&1; then
  APK_VC="$(aapt2 dump badging "$APK" 2>/dev/null | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p" | head -1)"
elif command -v aapt >/dev/null 2>&1; then
  APK_VC="$(aapt dump badging "$APK" 2>/dev/null | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p" | head -1)"
else
  APK_VC=""
fi
if [[ -z "$APK_VC" ]]; then
  echo "UYARI: aapt/aapt2 yok — versionCode dogrulanamadi." >&2
elif [[ "$APK_VC" != "$BUILD" ]]; then
  echo "HATA: APK versionCode=$APK_VC ama pubspec buildNumber=$BUILD." >&2
  echo "Yanlis APK'yi yayinlamak uzeresin." >&2
  exit 1
else
  echo "✓ $APK_VC (pubspec ile ayni)"
fi

# --- 3. Hash ve manifest --------------------------------------------------
SHA="$(sha256sum "$APK" | cut -d' ' -f1)"
echo
echo "--- sha256 ---"
echo "$SHA"

TAG="v$VERSION"
ASSET="$(basename "$APK")"
APK_URL="https://github.com/FurkanTahaBademci/NFCWrite/releases/download/$TAG/$ASSET"

python3 - "$MANIFEST" "$VERSION" "$BUILD" "$APK_URL" "$SHA" <<'PY'
import json, sys

path, version, build, apk_url, sha = sys.argv[1:6]

with open(path, encoding='utf-8') as f:
    data = json.load(f)

data['version'] = version
data['buildNumber'] = int(build)
data['apkUrl'] = apk_url
data['sha256'] = sha
data['forceUpdate'] = False

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')

print()
print('--- manifest guncellendi ---')
print(f'  version      {version}')
print(f'  buildNumber  {build}')
print(f'  apkUrl       {apk_url}')
print(f'  sha256       {sha}')
print()
print('DIKKAT: releaseNotes / releaseNotesEn ELLE guncellenmeli.')
print('Simdi surasi onemli — sira:')
print('  1. GitHub release olustur, APK\'yi TAM olarak yukaridaki apkUrl ile ekle')
print('  2. asset yerine oturduktan SONRA bu dosyayi main\'e push et')
print('Ters sirada push edersen kullanicilar indiremeyen bir guncelleme gorur.')
PY
