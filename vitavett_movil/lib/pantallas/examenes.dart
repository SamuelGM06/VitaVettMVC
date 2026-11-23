import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vitavett_movil/config/tema.dart';
import 'package:vitavett_movil/servicios/api_movil.dart';
import 'package:vitavett_movil/utilidades/formatos.dart';
import 'package:vitavett_movil/widgets/comunes.dart';

class ListaExamenes extends StatefulWidget {
  final int id;
  final String token;
  final Future<void> Function() onLogout;
  const ListaExamenes({super.key, required this.id, required this.token, required this.onLogout});
  @override
  State<ListaExamenes> createState() => _ListaExamenesState();
}

class _ListaExamenesState extends State<ListaExamenes> {
  late Future<List<Map<String, dynamic>>> consulta;
  int? descargando;
  @override
  void initState() { super.initState(); recargar(); }
  void recargar() => consulta = ApiMovil(token: widget.token).lista('/api/movil/mascotas/${widget.id}/examenes');

  Future<void> abrirArchivo(Map<String, dynamic> examen) async {
    final id = examen['id'] as int;
    setState(() => descargando = id);
    try {
      final bytes = await ApiMovil(token: widget.token)
          .descargar('/api/movil/mascotas/${widget.id}/examenes/$id/archivo');
      final carpeta = await getApplicationDocumentsDirectory();
      final nombre = (examen['nombreArchivo']?.toString() ?? 'examen.pdf')
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final archivo = File('${carpeta.path}/${id}_$nombre');
      await archivo.writeAsBytes(bytes, flush: true);
      final resultado = await OpenFilex.open(archivo.path);
      if (resultado.type != ResultType.done) {
        throw ApiError('Archivo descargado, pero no hay una aplicación compatible para abrirlo.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        if (e is ApiError && e.sesionExpirada) widget.onLogout();
      }
    } finally {
      if (mounted) setState(() => descargando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: consulta,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return MensajeError(error: snapshot.error!, onReintentar: () => setState(recargar), onLogout: widget.onLogout);
        final examenes = snapshot.data!;
        if (examenes.isEmpty) {
          return const EstadoVacio(icono: Icons.description_outlined, titulo: 'Sin exámenes todavía', texto: 'Los resultados que suba el veterinario aparecerán aquí.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: examenes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final e = examenes[i];
            final esPdf = e['tipoArchivo'] == 'application/pdf';
            return Entrada(
              orden: i,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: esPdf ? const Color(0xFFFEE2E2) : vvMenta,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(esPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                          color: esPdf ? const Color(0xFFB91C1C) : vvTeal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e['descripcion']?.toString() ?? 'Examen',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${fechaCorta(e['fechaSubida'])} · ${e['veterinario'] ?? ''}',
                            style: const TextStyle(color: vvTextoSuave, fontSize: 13)),
                        Text(e['nombreArchivo']?.toString() ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: vvTextoSuave, fontSize: 12)),
                      ]),
                    ),
                    descargando == e['id']
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton.filledTonal(
                            tooltip: 'Descargar y abrir',
                            icon: const Icon(Icons.download_rounded),
                            onPressed: () => abrirArchivo(e),
                          ),
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
