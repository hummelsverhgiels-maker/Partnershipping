import 'package:http/http.dart' as http;

import '../config.dart';

/// Отвечает ли сервер по адресу [base] (приложение на телефоне, без ограничений браузера).
Future<bool> probeServer(String base) async {
  try {
    final r = await http
        .get(
          Uri.parse('$base/auth/v1/health'),
          headers: {'apikey': kSupabaseAnonKey},
        )
        .timeout(const Duration(seconds: 5));
    return r.statusCode < 500;
  } catch (_) {
    return false;
  }
}

/// На телефоне перезапуск делается при следующем запуске приложения.
void reloadApp() {}
