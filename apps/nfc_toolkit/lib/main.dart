import 'package:flutter/material.dart';

import 'src/app/app.dart';
import 'src/di/app_dependencies.dart';

/// Uygulamanin giris noktasi.
///
/// Bagimliliklar burada bir kez kurulur ve `AppDependencies.wrap` ile
/// widget agacina baglanir. Bunun disinda hicbir yerde somut servis
/// olusturulmaz.
///
/// Bkz. `.claude/docs/01-architecture.md`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = await AppDependencies.bootstrap();

  runApp(dependencies.wrap(const NfcToolkitApp()));
}
