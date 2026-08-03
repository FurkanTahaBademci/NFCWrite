import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_toolkit/src/app/router.dart';

void main() {
  // Kabuk uygulamasinin testi sinirlidir: asil is feature ve servis
  // paketlerinde test edilir. Burada yalnizca yonlendiricinin
  // kurulabildigini dogruluyoruz — rota catismasi olursa burasi kirilir.
  test('yonlendirici hatasiz olusturulabiliyor', () {
    final router = createRouter();
    expect(router.configuration.routes, isNotEmpty);
  });
}
