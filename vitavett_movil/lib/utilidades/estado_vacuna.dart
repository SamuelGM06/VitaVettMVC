enum EstadoVacuna { vencida, pronto, alDia, renovada, unica }

// La API marca "vencida" solo en la última dosis de cada vacuna;
// una dosis anterior con fecha pasada ya fue renovada.
EstadoVacuna estadoVacuna(Map<String, dynamic> v, {DateTime? hoy}) {
  if (v['vencida'] == true) return EstadoVacuna.vencida;
  final proxima = DateTime.tryParse(v['proximaDosis']?.toString() ?? '');
  if (proxima == null) return EstadoVacuna.unica;
  final ahora = hoy ?? DateTime.now();
  final dia = DateTime(ahora.year, ahora.month, ahora.day);
  if (proxima.isBefore(dia)) return EstadoVacuna.renovada;
  if (proxima.difference(dia).inDays <= 30) return EstadoVacuna.pronto;
  return EstadoVacuna.alDia;
}
