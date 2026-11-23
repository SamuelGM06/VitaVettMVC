import 'package:flutter/material.dart';
import 'package:vitavett_movil/config/tema.dart';
import 'package:vitavett_movil/servicios/api_movil.dart';

/// Foto de la mascota, o la inicial de su especie sobre fondo menta.
class AvatarMascota extends StatelessWidget {
  final Map<String, dynamic> mascota;
  final String token;
  final double tamano;
  const AvatarMascota({super.key, required this.mascota, required this.token, this.tamano = 64});

  @override
  Widget build(BuildContext context) {
    final especie = mascota['especie']?.toString() ?? '';
    final inicial = Container(
      width: tamano,
      height: tamano,
      color: vvMenta,
      alignment: Alignment.center,
      child: especie.isEmpty
          ? Icon(Icons.pets, color: vvTeal, size: tamano * .5)
          : Text(especie[0].toUpperCase(),
              style: TextStyle(fontSize: tamano * .42, fontWeight: FontWeight.w700, color: vvTealOscuro)),
    );
    return Hero(
      tag: 'mascota-${mascota['id']}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tamano * .3),
        child: mascota['tieneFoto'] == true
            ? Image.network(
                ApiMovil(token: token).url('/api/movil/mascotas/${mascota['id']}/foto'),
                headers: {'Authorization': 'Bearer $token'},
                width: tamano, height: tamano, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => inicial,
              )
            : inicial,
      ),
    );
  }
}
