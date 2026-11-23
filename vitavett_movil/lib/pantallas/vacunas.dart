import 'package:flutter/material.dart';
import 'package:vitavett_movil/config/tema.dart';
import 'package:vitavett_movil/servicios/api_movil.dart';
import 'package:vitavett_movil/utilidades/estado_vacuna.dart';
import 'package:vitavett_movil/utilidades/formatos.dart';
import 'package:vitavett_movil/widgets/comunes.dart';

class ListaVacunas extends StatefulWidget {
  final int id;
  final String token;
  final Future<void> Function() onLogout;
  const ListaVacunas({super.key, required this.id, required this.token, required this.onLogout});
  @override
  State<ListaVacunas> createState() => _ListaVacunasState();
}

class _ListaVacunasState extends State<ListaVacunas> {
  late Future<List<Map<String, dynamic>>> consulta;
  @override
  void initState() { super.initState(); recargar(); }
  void recargar() => consulta = ApiMovil(token: widget.token).lista('/api/movil/mascotas/${widget.id}/vacunas');

  static const _estilos = {
    EstadoVacuna.vencida: ('Vencida', Color(0xFFFEE2E2), Color(0xFFB91C1C), Icons.warning_amber_rounded),
    EstadoVacuna.pronto: ('Renovar pronto', Color(0xFFFEF3C7), Color(0xFFB45309), Icons.schedule),
    EstadoVacuna.alDia: ('Al día', Color(0xFFDCFCE7), Color(0xFF15803D), Icons.check_circle_outline),
    EstadoVacuna.renovada: ('Renovada', Color(0xFFF1F5F9), vvTextoSuave, Icons.history),
    EstadoVacuna.unica: ('Dosis única', Color(0xFFF1F5F9), vvTextoSuave, Icons.done),
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: consulta,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return MensajeError(error: snapshot.error!, onReintentar: () => setState(recargar), onLogout: widget.onLogout);
        final vacunas = snapshot.data!;
        if (vacunas.isEmpty) {
          return const EstadoVacio(icono: Icons.vaccines, titulo: 'Sin vacunas registradas', texto: 'Aquí verás cada dosis que aplique el veterinario.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: vacunas.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final v = vacunas[i];
            final (texto, fondo, color, icono) = _estilos[estadoVacuna(v)]!;
            return Entrada(
              orden: i,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: v['vencida'] == true ? const Color(0xFFFCA5A5) : const Color(0xFFE2EBF0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: vvMenta, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.vaccines, color: vvTeal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(v['nombre']?.toString() ?? 'Vacuna',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                      Etiqueta(texto, fondo: fondo, color: color, icono: icono),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _Dato(titulo: 'Aplicada', valor: fechaCorta(v['fechaAplicacion']))),
                      Expanded(child: _Dato(titulo: 'Próxima dosis', valor: v['proximaDosis'] == null ? '—' : fechaCorta(v['proximaDosis']))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.medical_services_outlined, size: 16, color: vvTextoSuave),
                      const SizedBox(width: 6),
                      Expanded(child: Text(v['veterinario']?.toString() ?? '', style: const TextStyle(color: vvTextoSuave))),
                    ]),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo;
  final String valor;
  const _Dato({required this.titulo, required this.valor});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: .6, fontWeight: FontWeight.w600, color: vvTextoSuave)),
      const SizedBox(height: 2),
      Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    ]);
  }
}
