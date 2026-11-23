import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

// Ejecutar con --dart-define=API_BASE_URL=https://TU-SERVIDOR-PUBLICO
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5039', // Emulador Android + backend local
);
const FlutterSecureStorage almacenamiento = FlutterSecureStorage();

void main() => runApp(const VitaVettApp());

class ApiError implements Exception {
  final String mensaje;
  final bool sesionExpirada;
  const ApiError(this.mensaje, {this.sesionExpirada = false});
  @override
  String toString() => mensaje;
}

class ApiMovil {
  final String? token;
  const ApiMovil({this.token});

  String url(String ruta) => '${apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}$ruta';

  Map<String, String> get headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> solicitar(
    String ruta, {
    bool post = false,
    Map<String, dynamic>? datos,
  }) async {
    try {
      final uri = Uri.parse(url(ruta));
      final respuesta = await (post
              ? http.post(uri,
                  headers: {...headers, 'Content-Type': 'application/json'},
                  body: jsonEncode(datos ?? {}))
              : http.get(uri, headers: headers))
          .timeout(const Duration(seconds: 20));

      if (respuesta.statusCode == 401) {
        String mensaje = post
            ? 'Cédula o contraseña incorrectas, o usuario bloqueado.'
            : 'Tu sesión venció o ya no tienes acceso. Inicia sesión otra vez.';
        try {
          final body = jsonDecode(respuesta.body);
          if (body is Map && body['mensaje'] is String) mensaje = body['mensaje'];
        } catch (_) {}
        throw ApiError(mensaje, sesionExpirada: !post);
      }

      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        String mensaje = 'No se pudo completar la operación (HTTP ${respuesta.statusCode}).';
        try {
          final body = jsonDecode(respuesta.body);
          if (body is Map && body['mensaje'] is String) mensaje = body['mensaje'];
        } catch (_) {}
        throw ApiError(mensaje);
      }
      return respuesta;
    } on ApiError {
      rethrow;
    } on TimeoutException {
      throw const ApiError('El servidor tardó demasiado en responder.');
    } on SocketException {
      throw const ApiError('No hay conexión. Revisa tu internet o el servidor.');
    } on http.ClientException {
      throw const ApiError('No se pudo conectar con el servidor.');
    } on FormatException {
      throw const ApiError('La dirección del servidor no es válida.');
    }
  }

  Future<String> iniciarSesion(String cedula, String password) async {
    final respuesta = await solicitar('/api/movil/auth/login', post: true, datos: {
      'cedula': cedula.trim(),
      'password': password,
    });
    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
    return json['token'] as String;
  }

  Future<List<Map<String, dynamic>>> lista(String ruta) async {
    final respuesta = await solicitar(ruta);
    final datos = jsonDecode(respuesta.body) as List<dynamic>;
    return datos.map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }

  Future<List<int>> descargar(String ruta) async {
    final respuesta = await solicitar(ruta);
    return respuesta.bodyBytes;
  }
}

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

// Colores del tema web de VitaVett.
const Color vvTeal = Color(0xFF0D9488);
const Color vvTealOscuro = Color(0xFF115E59);
const Color vvAcento = Color(0xFFF59E0B);
const Color vvMenta = Color(0xFFE3F3F0);
const Color vvFondo = Color(0xFFF5F8FD);
const Color vvTextoSuave = Color(0xFF5B6B7A);

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

class PantallaLogin extends StatefulWidget {
  final Future<void> Function(String) onLogin;
  const PantallaLogin({super.key, required this.onLogin});
  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final formulario = GlobalKey<FormState>();
  final cedula = TextEditingController();
  final password = TextEditingController();
  bool procesando = false;
  bool verPassword = false;
  String? error;

  @override
  void dispose() {
    cedula.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> entrar() async {
    if (!formulario.currentState!.validate()) return;
    setState(() { procesando = true; error = null; });
    try {
      final token = await const ApiMovil().iniciarSesion(cedula.text, password.text);
      await widget.onLogin(token);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Entrada(
                child: Form(
                  key: formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/vitavett-logo.png', height: 84, semanticLabel: 'VitaVett'),
                      const SizedBox(height: 18),
                      const Text('El expediente de tu mascota,\nsiempre contigo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, color: vvTealOscuro)),
                      const SizedBox(height: 8),
                      const Text('Consulta sus vacunas y descarga sus exámenes.',
                          textAlign: TextAlign.center, style: TextStyle(color: vvTextoSuave)),
                      const SizedBox(height: 28),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            TextFormField(
                              controller: cedula,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Cédula', prefixIcon: Icon(Icons.badge_outlined)),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa tu cédula' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: password,
                              obscureText: !verPassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: verPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                                  icon: Icon(verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                  onPressed: () => setState(() => verPassword = !verPassword),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Ingresa tu contraseña' : null,
                              onFieldSubmitted: (_) => procesando ? null : entrar(),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: procesando ? null : entrar,
                              icon: procesando
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.login),
                              label: const Text('Iniciar sesión'),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Acceso para dueños de mascotas registradas en la clínica.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: vvTextoSuave)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
