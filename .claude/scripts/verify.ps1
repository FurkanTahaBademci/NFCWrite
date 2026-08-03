# NFC Toolkit - dogrulama betigi
# Kullanim:  pwsh .claude/scripts/verify.ps1
# Cikis kodu 0 = temiz, 1 = sorun var.

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root

$fail = 0

Write-Host "`n=== 1/4  Bicimlendirme ===" -ForegroundColor Cyan
dart format --output=none --set-exit-if-changed .
if ($LASTEXITCODE -ne 0) { Write-Host "  ! Bicimlendirilmemis dosyalar var: dart format ." -ForegroundColor Yellow }

Write-Host "`n=== 2/4  Statik analiz ===" -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { Write-Host "  X Analiz basarisiz" -ForegroundColor Red; $fail = 1 }
else { Write-Host "  + Temiz" -ForegroundColor Green }

Write-Host "`n=== 3/4  Testler ===" -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { Write-Host "  X Testler basarisiz" -ForegroundColor Red; $fail = 1 }
else { Write-Host "  + Hepsi gecti" -ForegroundColor Green }

Write-Host "`n=== 4/4  Mimari sinir denetimi ===" -ForegroundColor Cyan
$violations = @()

# feature_* paketleri servis paketlerine bagimli olamaz
Get-ChildItem "$root\packages\features" -Directory | ForEach-Object {
  $pubspec = Join-Path $_.FullName 'pubspec.yaml'
  if (Test-Path $pubspec) {
    $content = Get-Content $pubspec -Raw
    foreach ($banned in @('nfc_transport', 'tag_ops', 'storage:')) {
      if ($content -match "(?m)^\s+$([regex]::Escape($banned))") {
        $violations += "$($_.Name) -> $banned  (feature paketi servis paketine bagimli olamaz)"
      }
    }
    # kardes feature bagimliligi
    Get-ChildItem "$root\packages\features" -Directory | ForEach-Object {
      $other = $_.Name
      if ($other -ne $PSItem.Name -and $content -match "(?m)^\s+$other\s*:") {
        $violations += "$($PSItem.Name) -> $other  (kardes feature bagimliligi yasak)"
      }
    }
  }
}

# nfc_core saf Dart kalmali
$corePubspec = Get-Content "$root\packages\core\nfc_core\pubspec.yaml" -Raw
if ($corePubspec -match '(?m)^\s+flutter\s*:') {
  $violations += "nfc_core -> flutter  (nfc_core saf Dart olmali)"
}

# src/ sizintisi
$srcLeaks = Select-String -Path "$root\packages\**\lib\**\*.dart", "$root\apps\**\lib\**\*.dart" `
  -Pattern "import\s+'package:(\w+)/src/" -AllMatches -ErrorAction SilentlyContinue
foreach ($leak in $srcLeaks) {
  $owner = Split-Path (Split-Path (Split-Path $leak.Path -Parent) -Parent) -Leaf
  $imported = [regex]::Match($leak.Line, "package:(\w+)/src/").Groups[1].Value
  if ($owner -ne $imported) {
    $violations += "$($leak.Path):$($leak.LineNumber) -> package:$imported/src/  (src gizlidir)"
  }
}

if ($violations.Count -gt 0) {
  Write-Host "  X $($violations.Count) ihlal:" -ForegroundColor Red
  $violations | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
  $fail = 1
} else {
  Write-Host "  + Sinirlar temiz" -ForegroundColor Green
}

Write-Host ""
if ($fail -eq 0) { Write-Host "TUM KONTROLLER GECTI" -ForegroundColor Green }
else { Write-Host "DOGRULAMA BASARISIZ" -ForegroundColor Red }
exit $fail
