import 'dart:js_interop';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

final Map<String, String> _blobs = {};

/// Делает blob-ссылку на байты (живёт, пока открыта страница).
Future<String> localPlayable(String key, Uint8List bytes, String mime) async {
  final hit = _blobs[key];
  if (hit != null) return hit;
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  _blobs[key] = url;
  return url;
}

VideoPlayerController videoFromLocal(String local) =>
    VideoPlayerController.networkUrl(Uri.parse(local));

Source audioFromLocal(String local) => UrlSource(local);
