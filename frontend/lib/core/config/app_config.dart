/// App-wide configuration constants.
///
/// The API base URL is injected at build time via `--dart-define`:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
///
/// Defaults to the Android emulator's host-loopback address so a locally
/// running Node.js backend on the developer's machine is reachable.
class AppConfig {
  const AppConfig._();

  /// Base URL for the backend REST API.
  /// Override at build time with: --dart-define=API_BASE_URL=https://your-api.com/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  /// App name shown in the UI.
  static const String appName = 'Smart Shop Ledger';

  /// Default currency symbol used by formatters.
  static const String currencySymbol = '৳';

  /// Supported bKash / cash account types.
  static const List<String> accountTypes = [
    'agent_bKash',
    'personal_bKash',
    'physical_cash',
  ];

  /// All transaction types tracked by the ledger.
  static const List<String> transactionTypes = [
    'cash_in',
    'cash_out',
    'b2b_receive',
    'b2b_send',
    'send_money',
    'expense',
    'capital_add',
  ];

  /// User roles.
  static const String roleAdmin = 'admin';
  static const String roleStaff = 'staff';
}
