# Şablon — Yeni özellik paketi ekleme

Yeni bir `feature_<ad>` paketi eklerken bu adımları **eksiksiz** izle.

## 1. Klasör yapısı

```
packages/features/feature_<ad>/
├── lib/
│   ├── feature_<ad>.dart          # barrel — sadece export
│   └── src/
│       ├── application/
│       │   ├── providers.dart     # servis yer tutucuları (override edilir)
│       │   └── <ad>_controller.dart
│       ├── domain/
│       ├── presentation/
│       │   ├── pages/
│       │   └── widgets/
│       └── routes.dart
├── test/
├── analysis_options.yaml          # include: ../../../analysis_options.yaml
└── pubspec.yaml
```

## 2. pubspec.yaml

```yaml
name: feature_<ad>
description: <bir cümle>
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.12.0

resolution: workspace

dependencies:
  design_system: ^0.1.0
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.4.2
  go_router: ^17.3.0
  localization: ^0.1.0
  nfc_core: ^0.1.0
  shared_utils: ^0.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
```

> `nfc_transport`, `tag_ops`, `storage` veya başka bir `feature_*`
> **eklenmez.** Bu bir mimari ihlalidir.

## 3. Barrel dosyası

```dart
/// <Ad> özelliği.
library;

export 'src/application/providers.dart' show <ad>ServiceProvider;
export 'src/routes.dart' show <ad>Routes;
```

Sayfaları ve controller'ları **dışa açma** — dışarıdan yalnızca rotalar ve
override edilecek provider'lar görünür.

## 4. Servis yer tutucusu

```dart
// src/application/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_core/nfc_core.dart';

/// Composition root (`apps/nfc_toolkit`) tarafından override edilir.
final <ad>ServiceProvider = Provider<SomeContract>(
  (ref) => throw UnimplementedError(
    'apps/nfc_toolkit composition root içinde override edilmeli',
  ),
);
```

## 5. Rotalar

```dart
// src/routes.dart
final List<RouteBase> <ad>Routes = [
  GoRoute(
    path: '/<ad>',
    builder: (context, state) => const <Ad>Page(),
    routes: [ /* alt rotalar */ ],
  ),
];
```

## 6. Kayıt (T1 yapar)

- [ ] Kök `pubspec.yaml` → `workspace:` listesine ekle
- [ ] `apps/nfc_toolkit/pubspec.yaml` → `dependencies` ekle
- [ ] `apps/nfc_toolkit/lib/src/app/router.dart` → rotaları birleştir
- [ ] `apps/nfc_toolkit/lib/src/di/providers.dart` → override'ları ekle
- [ ] `flutter pub get` (kökten)

## 7. Belgeleme

- [ ] `.claude/docs/02-feature-matrix.md` → özellikleri ekle
- [ ] `.claude/docs/06-parallel-workflow.md` → sahiplik tablosuna ekle
- [ ] Bir track dosyasına görevleri ekle
