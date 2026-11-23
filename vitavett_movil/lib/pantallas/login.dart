import 'package:flutter/material.dart';
import 'package:vitavett_movil/config/tema.dart';
import 'package:vitavett_movil/servicios/api_movil.dart';
import 'package:vitavett_movil/widgets/comunes.dart';

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
