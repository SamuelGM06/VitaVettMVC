import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:vitavett_movil/config/api_config.dart';

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
