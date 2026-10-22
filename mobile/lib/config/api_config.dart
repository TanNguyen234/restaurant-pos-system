/// Override for physical devices: flutter run --dart-define=POS_API_BASE_URL=http://192.168.x.x:5138
/// Default resolves Android emulator host; desktop/web uses localhost via --dart-define.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'POS_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5138',
  );
}
