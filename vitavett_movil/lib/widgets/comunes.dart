import 'package:flutter/material.dart';
import 'package:vitavett_movil/config/tema.dart';
import 'package:vitavett_movil/servicios/api_movil.dart';

/// Aparece deslizándose hacia arriba; respeta "reducir movimiento" del sistema.
class Entrada extends StatelessWidget {
  final Widget child;
  final int orden;
  const Entrada({super.key, required this.child, this.orden = 0});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + 70 * orden.clamp(0, 6)),
      curve: Curves.easeOutCubic,
      builder: (context, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: hijo),
      ),
      child: child,
    );
  }
}

class Etiqueta extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;
  const Etiqueta(this.texto, {super.key, this.fondo = vvMenta, this.color = vvTealOscuro, this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icono != null) ...[Icon(icono, size: 14, color: color), const SizedBox(width: 4)],
        Text(texto, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const EstadoVacio({super.key, required this.icono, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    // ListView para que el gesto de "jalar para actualizar" funcione también vacío.
    return ListView(padding: const EdgeInsets.all(32), children: [
      const SizedBox(height: 40),
      Center(
        child: Container(
          width: 88, height: 88,
          decoration: const BoxDecoration(color: vvMenta, shape: BoxShape.circle),
          child: Icon(icono, size: 42, color: vvTeal),
        ),
      ),
      const SizedBox(height: 18),
      Text(titulo, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: vvTealOscuro)),
      const SizedBox(height: 6),
      Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: vvTextoSuave)),
    ]);
  }
}

class MensajeError extends StatelessWidget {
  final Object error;
  final VoidCallback onReintentar;
  final Future<void> Function() onLogout;
  const MensajeError({super.key, required this.error, required this.onReintentar, required this.onLogout});
  @override
  Widget build(BuildContext context) {
    final esSesion = error is ApiError && (error as ApiError).sesionExpirada;
    return Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
          child: Icon(esSesion ? Icons.lock_clock_outlined : Icons.wifi_off, size: 38, color: const Color(0xFFB45309)),
        ),
        const SizedBox(height: 16),
        Text(error.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: esSesion ? onLogout : onReintentar,
          child: Text(esSesion ? 'Volver a iniciar sesión' : 'Reintentar'),
        ),
      ]),
    ));
  }
}
