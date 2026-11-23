import 'package:flutter/material.dart';
import 'package:vitavett_movil/config/tema.dart';
import 'package:vitavett_movil/pantallas/examenes.dart';
import 'package:vitavett_movil/pantallas/vacunas.dart';
import 'package:vitavett_movil/widgets/avatar_mascota.dart';

class PantallaExpediente extends StatelessWidget {
  final Map<String, dynamic> mascota;
  final String token;
  final Future<void> Function() onLogout;
  const PantallaExpediente({super.key, required this.mascota, required this.token, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final raza = mascota['raza']?.toString();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Expediente')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  AvatarMascota(mascota: mascota, token: token, tamano: 76),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(mascota['nombre']?.toString() ?? 'Mascota',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: vvTealOscuro)),
                      const SizedBox(height: 4),
                      Text([mascota['especie'], if (raza != null && raza.isNotEmpty) raza].join(' · '),
                          style: const TextStyle(color: vvTextoSuave)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: vvMenta, borderRadius: BorderRadius.circular(14)),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
              labelColor: vvTealOscuro,
              unselectedLabelColor: vvTextoSuave,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(height: 42, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.vaccines, size: 18), SizedBox(width: 6), Text('Vacunas')])),
                Tab(height: 42, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.description_outlined, size: 18), SizedBox(width: 6), Text('Exámenes')])),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              ListaVacunas(id: mascota['id'] as int, token: token, onLogout: onLogout),
              ListaExamenes(id: mascota['id'] as int, token: token, onLogout: onLogout),
            ]),
          ),
        ]),
      ),
    );
  }
}
