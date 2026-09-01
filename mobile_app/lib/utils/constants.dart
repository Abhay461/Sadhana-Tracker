/// App constants with secure environment configuration.
class Constants {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '',
  );

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Returns true if app is running in production environment.
  static bool get isProduction => environment == 'production';

  /// Validates environment configuration at runtime.
  static void validate() {
    if (isProduction && apiBaseUrl.contains('10.0.2.2')) {
      assert(false, 'CRITICAL: Production build cannot use emulator 10.0.2.2 backend URL.');
    }
  }
}
