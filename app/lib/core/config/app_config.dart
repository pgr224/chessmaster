/// Public endpoints supplied at build time, without a startup asset request.
class AppConfig {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://chess-master-api.pp942920.workers.dev',
  );

  static final wsUrl = const String.fromEnvironment('WS_URL').isNotEmpty
      ? const String.fromEnvironment('WS_URL')
      : Uri.parse(apiUrl)
          .replace(scheme: Uri.parse(apiUrl).scheme == 'https' ? 'wss' : 'ws')
          .toString();
}
