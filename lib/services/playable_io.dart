import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

final Map<String, String> _files = {};

/// Сохраняет байты во временный файл и возвращает путь к нему.
Future<String> localPlayable(String key, Uint8List bytes, String mime) async {
  final hit = _files[key];
  if (hit != null && File(hit).existsSync()) return hit;
  final base = await getTemporaryDirectory();
  final dir = Directory('${base.path}/vv_media');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final f = File('${dir.path}/$safe');
  if (!f.existsSync() || f.lengthSync() != bytes.length) {
    await f.writeAsBytes(bytes, flush: true);
  }
  _files[key] = f.path;
  return f.path;
}

VideoPlayerController videoFromLocal(String local) =>
    VideoPlayerController.file(File(local));

Source audioFromLocal(String local) => DeviceFileSource(local);
