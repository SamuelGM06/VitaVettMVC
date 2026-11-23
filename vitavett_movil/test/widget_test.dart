import 'package:flutter_test/flutter_test.dart';
import 'package:vitavett_movil/main.dart';

void main() {
  test('Muestra las fechas de la API en formato local', () {
    expect(fechaCorta('2026-11-23'), '23/11/2026');
    expect(fechaCorta(null), 'No definida');
  });

  test('Detecta vencimiento de una dosis anterior', () {
    expect(vacunaVencida('2020-01-01'), isTrue);
  });
}
