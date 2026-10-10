/// App constants with secure environment configuration.
class Constants {
  static const String _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sadhana-tracker-qq6m.onrender.com/api/v1',
  );

  /// Normalized API base URL without trailing slash.
  static String get apiBaseUrl {
    final trimmed = _rawApiBaseUrl.trim();
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '',
  );

  /// Checks if OneSignal App ID is properly configured with a valid non-placeholder value.
  static bool get isOneSignalConfigured {
    final id = oneSignalAppId.trim();
    return id.isNotEmpty && !id.toUpperCase().contains('YOUR_ONESIGNAL');
  }

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
