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

  test('Estado de cada dosis de vacuna', () {
    final hoy = DateTime(2026, 11, 23);
    expect(estadoVacuna({'vencida': true, 'proximaDosis': '2026-01-01'}, hoy: hoy), EstadoVacuna.vencida);
    expect(estadoVacuna({'vencida': false, 'proximaDosis': '2026-01-01'}, hoy: hoy), EstadoVacuna.renovada);
    expect(estadoVacuna({'vencida': false, 'proximaDosis': '2026-12-10'}, hoy: hoy), EstadoVacuna.pronto);
    expect(estadoVacuna({'vencida': false, 'proximaDosis': '2027-06-01'}, hoy: hoy), EstadoVacuna.alDia);
    expect(estadoVacuna({'vencida': false, 'proximaDosis': null}, hoy: hoy), EstadoVacuna.unica);
  });
}
