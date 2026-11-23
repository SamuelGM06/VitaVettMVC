import 'package:flutter/material.dart';
import 'package:vitavett_movil/config/tema.dart';
import 'package:vitavett_movil/pantallas/expediente.dart';
import 'package:vitavett_movil/servicios/api_movil.dart';
import 'package:vitavett_movil/widgets/avatar_mascota.dart';
import 'package:vitavett_movil/widgets/comunes.dart';

class PantallaMascotas extends StatefulWidget {
  final String token;
  final Future<void> Function() onLogout;
  const PantallaMascotas({super.key, required this.token, required this.onLogout});
  @override
  State<PantallaMascotas> createState() => _PantallaMascotasState();
}

class _PantallaMascotasState extends State<PantallaMascotas> {
  late Future<List<Map<String, dynamic>>> consulta;

  @override
  void initState() {
    super.initState();
    actualizar();
  }

  void actualizar() => consulta = ApiMovil(token: widget.token).lista('/api/movil/mascotas');

  Future<void> refrescar() async {
    setState(actualizar);
    try { await consulta; } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/vitavett-logo.png', height: 32, semanticLabel: 'VitaVett'),
        actions: [
          IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: () => setState(actualizar)),
          IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: consulta,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return MensajeError(error: snapshot.error!, onReintentar: () => setState(actualizar), onLogout: widget.onLogout);
          final mascotas = snapshot.data!;
          return RefreshIndicator(
            onRefresh: refrescar,
            child: mascotas.isEmpty
                ? const EstadoVacio(
                    icono: Icons.pets,
                    titulo: 'Todavía no hay mascotas',
                    texto: 'Cuando la clínica registre a tu mascota, aparecerá aquí.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: mascotas.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Entrada(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Mis mascotas',
                                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: vvTealOscuro)),
                              Text(mascotas.length == 1 ? '1 mascota registrada' : '${mascotas.length} mascotas registradas',
                                  style: const TextStyle(color: vvTextoSuave)),
                            ]),
                          ),
                        );
                      }
                      final m = mascotas[i - 1];
                      return Entrada(orden: i, child: TarjetaMascota(mascota: m, token: widget.token, onLogout: widget.onLogout));
                    },
                  ),
          );
        },
      ),
    );
  }
}

class TarjetaMascota extends StatelessWidget {
  final Map<String, dynamic> mascota;
  final String token;
  final Future<void> Function() onLogout;
  const TarjetaMascota({super.key, required this.mascota, required this.token, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final raza = mascota['raza']?.toString();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PantallaExpediente(mascota: mascota, token: token, onLogout: onLogout),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            AvatarMascota(mascota: mascota, token: token, tamano: 68),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mascota['nombre']?.toString() ?? 'Mascota',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Etiqueta(mascota['especie']?.toString() ?? ''),
                  if (raza != null && raza.isNotEmpty)
                    Etiqueta(raza, fondo: const Color(0xFFF1F5F9), color: vvTextoSuave),
                ]),
              ]),
            ),
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(color: vvMenta, shape: BoxShape.circle),
              child: const Icon(Icons.chevron_right, color: vvTeal),
            ),
          ]),
        ),
      ),
    );
  }
}
