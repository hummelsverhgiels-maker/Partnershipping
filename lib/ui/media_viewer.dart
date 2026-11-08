import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/store.dart';
import '../models.dart';
import '../services/media_service.dart';
import 'theme.dart';

Future<void> openFileExternally(BuildContext context, String path) async {
  try {
    final url = await MediaService.url(path);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть файл. Проверьте интернет.'),
        ),
      );
    }
  }
}

/// Полноэкранный просмотр фото или видео.
class MediaViewer extends StatefulWidget {
  final AppStore store;
  final Rec message;
  const MediaViewer({super.key, required this.store, required this.message});

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _video;
  String? _url;
  String? _error;

  bool get _isVideo => widget.message.s('type') == 'video';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await MediaService.url(widget.message.s('path')!);
      if (_isVideo) {
        final c = VideoPlayerController.networkUrl(Uri.parse(url));
        await c.initialize();
        c.addListener(() {
          if (mounted) setState(() {});
        });
        c.play();
        _video = c;
      }
      if (mounted) setState(() => _url = url);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Не удалось загрузить. Проверьте интернет.');
      }
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final important = widget.store.recById(m.id)?.b('important') ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          m.s('name') ?? '',
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Важное',
            icon: Icon(
              important ? Icons.star_rounded : Icons.star_border_rounded,
              color: important ? const Color(0xFFFFD36B) : Colors.white,
            ),
            onPressed: () {
              final cur = widget.store.recById(m.id);
              if (cur != null) widget.store.toggleImportant(cur);
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Открыть или скачать',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openFileExternally(context, m.s('path')!),
          ),
        ],
      ),
      body: Center(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.white));
    }
    if (_url == null) return const CircularProgressIndicator();
    if (_isVideo) {
      final c = _video!;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          const SizedBox(height: 8),
          VideoProgressIndicator(c, allowScrubbing: true),
          const SizedBox(height: 12),
          IconButton(
            iconSize: 56,
            color: Colors.white,
            icon: Icon(
              c.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
            ),
            onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
          ),
        ],
      );
    }
    return FutureBuilder<Uint8List>(
      future: MediaService.bytes(widget.message.s('path')!),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Не удалось загрузить фото.\n\n${snap.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        if (!snap.hasData) return const CircularProgressIndicator();
        return InteractiveViewer(
          maxScale: 5,
          child: Image.memory(
            snap.data!,
            fit: BoxFit.contain,
            errorBuilder: (c, e, st) => Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Файл скачан (${fmtSize(snap.data!.length)}), но не открывается как картинка.\n\n$e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Проигрыватель голосового сообщения.
class VoicePlayer extends StatefulWidget {
  final String path;
  final int? durationMs;
  final Color? color;
  final Color? softColor;
  const VoicePlayer({
    super.key,
    required this.path,
    this.durationMs,
    this.color,
    this.softColor,
  });

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  static AudioPlayer? _current;
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _loading = false;
  Duration _pos = Duration.zero;
  Duration? _dur;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
      if (s == PlayerState.completed) setState(() => _pos = Duration.zero);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
  }

  @override
  void dispose() {
    if (_current == _player) _current = null;
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_current != null && _current != _player) {
      await _current!.pause();
    }
    _current = _player;
    setState(() => _loading = true);
    try {
      if (_pos > Duration.zero && _dur != null) {
        await _player.resume();
      } else {
        final url = await MediaService.url(widget.path);
        await _player.play(UrlSource(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось воспроизвести')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur?.inMilliseconds ?? widget.durationMs ?? 0;
    final progress = total > 0
        ? (_pos.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _loading
            ? const SizedBox(
                width: 40,
                height: 40,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : IconButton(
                onPressed: _toggle,
                icon: Icon(
                  _playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 38,
                  color: widget.color ?? kInk,
                ),
              ),
        SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: (widget.color ?? kInk).withValues(alpha: 0.18),
                color: widget.color ?? kInk,
              ),
              const SizedBox(height: 4),
              Text(
                '${fmtDuration(_playing || _pos > Duration.zero ? _pos.inMilliseconds : total)}'
                ' / ${fmtDuration(total)}',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.softColor ?? kInkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
