// lib/utils/api_config.dart
class ApiConfig {
  /// Set your local or production IP here
  static const String _ip = '192.168.1.6';

  /// Base API URL for authenticated/standard endpoints
  static String get baseUrl => 'http://$_ip:5000/api';

  /// Optional: Direct access to specific endpoints
  static String get initCheckUrl => '${baseUrl}/init-check';
  static String get userProfileUrl => '${baseUrl}/user';
}
