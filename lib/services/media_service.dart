import 'package:file_picker/file_picker.dart';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../data/backend.dart';
import '../models.dart';
import '../util.dart';

/// Файл, выбранный или записанный пользователем (ещё не загруженный).
class PickedMedia {
  final String type; // image | video | audio | file
  final String name;
  final String contentType;
  final Uint8List bytes;
  final int? durationMs;
  const PickedMedia({
    required this.type,
    required this.name,
    required this.contentType,
    required this.bytes,
    this.durationMs,
  });
}

String fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} КБ';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
}

String fmtDuration(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class MediaService {
  /// Лимит бесплатного хранилища Supabase на один файл.
  static const maxBytes = 50 * 1024 * 1024;

  static final _picker = ImagePicker();

  static final Map<String, ({Future<String> url, DateTime at})> _urls = {};

  static String _ext(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  static String contentTypeFor(String name, {String? fallback}) {
    switch (_ext(name)) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
    }
    return fallback ?? 'application/octet-stream';
  }

  static void _checkSize(int bytes) {
    if (bytes > maxBytes) {
      throw 'Файл больше 50 МБ. Выберите поменьше или обрежьте видео.';
    }
  }

  static Future<PickedMedia?> pickImage(
    ImageSource source, {
    double maxSide = 1600,
    int quality = 80,
  }) async {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    _checkSize(bytes.length);
    var name = x.name.isEmpty ? 'photo.jpg' : x.name;
    if (_ext(name).isEmpty) name = '$name.jpg';
    return PickedMedia(
      type: 'image',
      name: name,
      contentType: contentTypeFor(name, fallback: x.mimeType ?? 'image/jpeg'),
      bytes: bytes,
    );
  }

  static Future<PickedMedia?> pickVideo(ImageSource source) async {
    final x = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    _checkSize(bytes.length);
    var name = x.name.isEmpty ? 'video.mp4' : x.name;
    if (_ext(name).isEmpty) name = '$name.mp4';
    return PickedMedia(
      type: 'video',
      name: name,
      contentType: contentTypeFor(name, fallback: x.mimeType ?? 'video/mp4'),
      bytes: bytes,
    );
  }

  static Future<PickedMedia?> pickFile() async {
    final f = await FilePicker.pickFile();
    if (f == null) return null;
    final bytes = await f.xFile.readAsBytes();
    _checkSize(bytes.length);
    return PickedMedia(
      type: 'file',
      name: f.name,
      contentType: contentTypeFor(f.name),
      bytes: bytes,
    );
  }

  static final Map<String, Future<Uint8List>> _bytesFutures = {};
  static final Map<String, int> _bytesSize = {};
  static final List<String> _bytesOrder = [];
  static int _bytesTotal = 0;

  /// Содержимое картинки целиком. Один и тот же Future отдаём всем, кто спрашивает,
  /// поэтому экран не мигает и картинка не скачивается повторно.
  static Future<Uint8List> bytes(String path) {
    final hit = _bytesFutures[path];
    if (hit != null) {
      _bytesOrder
        ..remove(path)
        ..add(path);
      return hit;
    }
    final f = _download(path);
    _bytesFutures[path] = f;
    _bytesOrder.add(path);
    f.then(
      (b) {
        _bytesSize[path] = b.length;
        _bytesTotal += b.length;
        // держим в памяти не больше ~60 МБ картинок
        while (_bytesTotal > 60 * 1024 * 1024 && _bytesOrder.length > 1) {
          final old = _bytesOrder.removeAt(0);
          _bytesFutures.remove(old);
          _bytesTotal -= _bytesSize.remove(old) ?? 0;
        }
      },
      onError: (Object _) {
        _bytesFutures.remove(path);
        _bytesOrder.remove(path);
      },
    );
    return f;
  }

  static Future<Uint8List> _download(String path) async {
    final url = await Backend.signedUrl(path);
    final candidates = <String>[url, ?Backend.alternate(url)];
    Object? lastError;
    for (final u in candidates) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final r = await http
              .get(Uri.parse(u))
              .timeout(const Duration(seconds: 45));
          if (r.statusCode == 200) return r.bodyBytes;
          throw 'Сервер вернул код ${r.statusCode} (${r.reasonPhrase ?? ''})';
        } catch (e) {
          lastError = e;
          if (e is String) rethrow; // отказ сервера: повторять незачем
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    throw lastError ?? 'Не удалось скачать файл';
  }

  /// Android может закрыть приложение, пока открыта камера. Тогда снимок
  /// «теряется». Здесь забираем его обратно.
  static Future<PickedMedia?> recoverLost() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final r = await _picker.retrieveLostData();
      if (r.isEmpty) return null;
      final x = r.file ?? (r.files?.isNotEmpty == true ? r.files!.first : null);
      if (x == null) return null;
      final bytes = await x.readAsBytes();
      _checkSize(bytes.length);
      final isVideo = r.type == RetrieveType.video;
      var name = x.name.isEmpty
          ? (isVideo ? 'video.mp4' : 'photo.jpg')
          : x.name;
      if (_ext(name).isEmpty) name = isVideo ? '$name.mp4' : '$name.jpg';
      return PickedMedia(
        type: isVideo ? 'video' : 'image',
        name: name,
        contentType: contentTypeFor(name),
        bytes: bytes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Загрузить файл в хранилище пары; возвращает путь в хранилище.
  static Future<String> upload(
    PairSession s,
    PickedMedia m, {
    String? folder,
  }) async {
    final ext = _ext(m.name);
    final dir = folder == null ? s.pairId : '${s.pairId}/$folder';
    final path = '$dir/${newId()}${ext.isEmpty ? '' : '.$ext'}';
    await Backend.uploadFile(path, m.bytes, m.contentType);
    return path;
  }

  /// Временная ссылка на файл. Одну и ту же ссылку отдаём 50 минут,
  /// чтобы картинки не перезагружались.
  static Future<String> url(String path) {
    final c = _urls[path];
    if (c != null &&
        DateTime.now().difference(c.at) < const Duration(minutes: 50)) {
      return c.url;
    }
    final f = Backend.signedUrl(path);
    _urls[path] = (url: f, at: DateTime.now());
    f.catchError((Object _) {
      _urls.remove(path);
      return '';
    });
    return f;
  }
}

/// Запись голосового сообщения.
class VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();
  AudioEncoder _enc = AudioEncoder.aacLc;
  DateTime? _started;

  String get _ext => switch (_enc) {
    AudioEncoder.aacLc => 'm4a',
    AudioEncoder.opus => kIsWeb ? 'webm' : 'opus',
    _ => 'wav',
  };

  String get _contentType => switch (_enc) {
    AudioEncoder.aacLc => 'audio/mp4',
    AudioEncoder.opus => kIsWeb ? 'audio/webm' : 'audio/ogg',
    _ => 'audio/wav',
  };

  /// false, если нет разрешения на микрофон.
  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    for (final e in [AudioEncoder.aacLc, AudioEncoder.opus, AudioEncoder.wav]) {
      if (await _rec.isEncoderSupported(e)) {
        _enc = e;
        break;
      }
    }
    var path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$_ext';
    }
    await _rec.start(RecordConfig(encoder: _enc), path: path);
    _started = DateTime.now();
    return true;
  }

  Future<PickedMedia?> stop() async {
    final p = await _rec.stop();
    final started = _started;
    _started = null;
    if (p == null || started == null) return null;
    final bytes = await XFile(p).readAsBytes();
    _checkSizeSafe(bytes.length);
    final ms = DateTime.now().difference(started).inMilliseconds;
    return PickedMedia(
      type: 'audio',
      name: 'voice_${DateTime.now().millisecondsSinceEpoch}.$_ext',
      contentType: _contentType,
      bytes: bytes,
      durationMs: ms,
    );
  }

  void _checkSizeSafe(int n) {
    if (n > MediaService.maxBytes) throw 'Голосовое слишком длинное';
  }

  Future<void> cancel() async {
    _started = null;
    try {
      await _rec.cancel();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _rec.dispose();
    } catch (_) {}
  }
}
