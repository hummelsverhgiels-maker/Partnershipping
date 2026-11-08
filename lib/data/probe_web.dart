import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// В браузере обычный запрос может быть отклонён правилами безопасности (CORS)
/// даже при рабочей сети. Поэтому проверяем «вслепую» (no-cors): запрос
/// завершится, если до сервера можно достучаться, и упадёт, если путь заблокирован.
Future<bool> probeServer(String base) async {
  try {
    final init = web.RequestInit(mode: 'no-cors', cache: 'no-store');
    await web.window
        .fetch('$base/auth/v1/health'.toJS, init)
        .toDart
        .timeout(const Duration(seconds: 5));
    return true;
  } catch (_) {
    return false;
  }
}
