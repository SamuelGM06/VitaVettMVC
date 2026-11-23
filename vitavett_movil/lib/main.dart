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
    return MaterialApp(
      navigatorKey: _navegador,
      title: 'VitaVett',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF147B69)),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
      ),
      home: _cargando
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _token == null
              ? PantallaLogin(onLogin: _iniciar)
              : PantallaMascotas(token: _token!, onLogout: _salir),
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
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.pets_rounded, size: 74, color: Color(0xFF147B69)),
                    const SizedBox(height: 12),
                    Text('VitaVett', textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text('Expediente de tus mascotas', textAlign: TextAlign.center),
                    const SizedBox(height: 35),
                    TextFormField(
                      controller: cedula,
                      decoration: const InputDecoration(labelText: 'Cédula', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge_outlined)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa tu cédula' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                      validator: (v) => v == null || v.isEmpty ? 'Ingresa tu contraseña' : null,
                      onFieldSubmitted: (_) => procesando ? null : entrar(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: procesando ? null : entrar,
                      icon: procesando ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                      label: const Text('Iniciar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis mascotas'),
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
          if (mascotas.isEmpty) return const Center(child: Text('Todavía no tienes mascotas registradas.'));
          return RefreshIndicator(
            onRefresh: () async {
              setState(actualizar);
              try { await consulta; } catch (_) {}
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: mascotas.length,
              itemBuilder: (context, i) {
                final m = mascotas[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: m['tieneFoto'] == true
                          ? Image.network(
                              ApiMovil(token: widget.token).url('/api/movil/mascotas/${m['id']}/foto'),
                              headers: {'Authorization': 'Bearer ${widget.token}'},
                              width: 64, height: 64, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 48),
                            )
                          : const SizedBox(width: 64, height: 64, child: Icon(Icons.pets, size: 40)),
                    ),
                    title: Text(m['nombre']?.toString() ?? 'Mascota', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${m['especie'] ?? ''} · ${m['raza'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PantallaExpediente(
                        mascota: m, token: widget.token, onLogout: widget.onLogout),
                    )),
                  ),
                );
              },
            ),
          );
        },
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Expediente de ${mascota['nombre']}'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.vaccines), text: 'Vacunas'),
            Tab(icon: Icon(Icons.description), text: 'Exámenes'),
          ]),
        ),
        body: TabBarView(children: [
          ListaVacunas(id: mascota['id'] as int, token: token, onLogout: onLogout),
          ListaExamenes(id: mascota['id'] as int, token: token, onLogout: onLogout),
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
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(esSesion ? Icons.lock_clock_outlined : Icons.wifi_off, size: 46),
        const SizedBox(height: 12),
        Text(error.toString(), textAlign: TextAlign.center),
        const SizedBox(height: 14),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: consulta,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return MensajeError(error: snapshot.error!, onReintentar: () => setState(recargar), onLogout: widget.onLogout);
        final vacunas = snapshot.data!;
        if (vacunas.isEmpty) return const Center(child: Text('No hay vacunas registradas.'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: vacunas.length,
          itemBuilder: (context, i) {
            final v = vacunas[i];
            final vencida = vacunaVencida(v['proximaDosis']);
            return Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(v['nombre']?.toString() ?? 'Vacuna', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                  if (vencida) const Chip(label: Text('Vencida'), backgroundColor: Color(0xFFFFDADA)),
                ]),
                Text('Aplicación: ${fechaCorta(v['fechaAplicacion'])}'),
                Text('Próxima dosis: ${fechaCorta(v['proximaDosis'])}'),
                Text('Veterinario: ${v['veterinario'] ?? ''}'),
              ]),
            ));
          },
        );
      },
    );
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
        if (examenes.isEmpty) return const Center(child: Text('No hay resultados de exámenes.'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: examenes.length,
          itemBuilder: (context, i) {
            final e = examenes[i];
            final esPdf = e['tipoArchivo'] == 'application/pdf';
            return Card(child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: Icon(esPdf ? Icons.picture_as_pdf : Icons.image_outlined, size: 36),
              title: Text(e['descripcion']?.toString() ?? 'Examen', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${e['nombreArchivo'] ?? ''}\n${fechaCorta(e['fechaSubida'])}\n${e['veterinario'] ?? ''}'),
              isThreeLine: true,
              trailing: descargando == e['id']
                  ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      tooltip: 'Descargar y abrir',
                      icon: const Icon(Icons.file_download_outlined),
                      onPressed: () => abrirArchivo(e),
                    ),
            ));
          },
        );
      },
    );
  }
}
