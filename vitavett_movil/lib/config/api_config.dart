// Ejecutar con --dart-define=API_BASE_URL=https://TU-SERVIDOR-PUBLICO
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://vitavettmvc.onrender.com',
);
