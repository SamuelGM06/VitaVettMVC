import 'package:flutter/material.dart';
import 'package:vitavett_movil/config/tema.dart';
import 'package:vitavett_movil/pantallas/login.dart';
import 'package:vitavett_movil/pantallas/mascotas.dart';
import 'package:vitavett_movil/servicios/almacenamiento.dart';

// Se re-exportan para que el código existente (por ejemplo, las pruebas) siga importando desde main.dart.
export 'package:vitavett_movil/servicios/api_movil.dart';
export 'package:vitavett_movil/utilidades/estado_vacuna.dart';
export 'package:vitavett_movil/utilidades/formatos.dart';

void main() => runApp(const VitaVettApp());

class VitaVettApp extends StatefulWidget {
  const VitaVettApp({super.key});
  @override
  State<VitaVettApp> createState() => _VitaVettAppState();
}

class _VitaVettAppState extends State<VitaVettApp> {
  final _navegador = GlobalKey<NavigatorState>();
  String? _token;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _recuperarSesion();
  }

  Future<void> _recuperarSesion() async {
    try {
      final guardado = await almacenamiento.read(key: 'jwt_vitavett');
      if (mounted) setState(() => _token = guardado);
    } catch (_) {
      // Si el almacenamiento seguro no está disponible, se pide iniciar sesión.
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _iniciar(String token) async {
    await almacenamiento.write(key: 'jwt_vitavett', value: token);
    if (mounted) setState(() => _token = token);
  }

  Future<void> _salir() async {
    try {
      await almacenamiento.delete(key: 'jwt_vitavett');
    } catch (_) {}
    _navegador.currentState?.popUntil((ruta) => ruta.isFirst);
    if (mounted) setState(() => _token = null);
  }

  @override
  Widget build(BuildContext context) {
    final esquema = ColorScheme.fromSeed(seedColor: vvTeal, primary: vvTeal, secondary: vvAcento, surface: Colors.white);
    final bordeCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD5E1E8)),
    );
    return MaterialApp(
      navigatorKey: _navegador,
      title: 'VitaVett',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: esquema,
        scaffoldBackgroundColor: vvFondo,
        appBarTheme: const AppBarTheme(
          backgroundColor: vvFondo,
          foregroundColor: vvTealOscuro,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(color: vvTealOscuro, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2EBF0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: bordeCampo,
          enabledBorder: bordeCampo,
          focusedBorder: bordeCampo.copyWith(borderSide: const BorderSide(color: vvTeal, width: 2)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: _cargando
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _token == null
              ? PantallaLogin(onLogin: _iniciar)
              : PantallaMascotas(token: _token!, onLogout: _salir),
    );
  }
}
