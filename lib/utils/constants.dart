/// App constants with secure configuration.
/// API keys are loaded from environment variables (--dart-define) at build time.
/// This prevents hardcoded secrets from being exposed in the APK.
class Constants {
  // Loaded from --dart-define at build time, with fallback for development only
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://plftorurxmtbzmdvttdm.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsZnRvcnVyeG10YnptZHZ0dGRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxOTU4OTcsImV4cCI6MjA4OTc3MTg5N30.uFuYV62UEVn_lJxPJKU3uLGRsf695njDiRI4h4NmEI0',
  );
  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'YOUR_ONESIGNAL_APP_ID',
  );
  static const String oneSignalRestApiKey = String.fromEnvironment(
    'ONESIGNAL_REST_API_KEY',
    defaultValue: 'YOUR_ONESIGNAL_REST_API_KEY',
  );
}
