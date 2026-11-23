String fechaCorta(Object? valor) {
  if (valor == null) return 'No definida';
  final texto = valor.toString();
  if (texto.length < 10) return texto;
  final fecha = texto.substring(0, 10).split('-');
  if (fecha.length != 3) return texto;
  return '${fecha[2]}/${fecha[1]}/${fecha[0]}';
}

bool vacunaVencida(Object? valor) {
  if (valor == null) return false;
  final fecha = DateTime.tryParse(valor.toString());
  if (fecha == null) return false;
  final hoy = DateTime.now();
  return fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
}
