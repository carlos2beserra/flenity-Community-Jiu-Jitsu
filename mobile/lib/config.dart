/// URL da API. Defina na build: `flutter run --dart-define=API_URL=https://sua-academia.com/api`
/// No emulador Android, o host da máquina é 10.0.2.2 (ex.: http://10.0.2.2:8080/api).
const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080/api');
