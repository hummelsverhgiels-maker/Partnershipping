import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/media_service.dart';
import 'theme.dart';

/// Миниатюра фото. Картинка скачивается один раз, хранится в памяти и
/// показывается уменьшенной (так экран не тормозит).
class ImageThumb extends StatefulWidget {
  final String path;
  final double? width;
  final double? height;
  final VoidCallback onTap;
  const ImageThumb({
    super.key,
    required this.path,
    this.width,
    this.height,
    required this.onTap,
  });

  @override
  State<ImageThumb> createState() => ImageThumbState();
}

class ImageThumbState extends State<ImageThumb> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = MediaService.bytes(widget.path);
  }

  @override
  void didUpdateWidget(covariant ImageThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _future = MediaService.bytes(widget.path);
    }
  }

  Widget _placeholder({Widget? child}) => ColoredBox(
    color: kPlaceholder,
    child: Center(child: child),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, c) {
              final dpr = MediaQuery.of(context).devicePixelRatio;
              final w = (c.maxWidth.isFinite ? c.maxWidth : 220) * dpr;
              final cacheW = w.round().clamp(96, 720);
              return FutureBuilder<Uint8List>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _placeholder(
                      child: const Icon(Icons.broken_image_outlined),
                    );
                  }
                  if (!snap.hasData) {
                    return _placeholder(
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return Image.memory(
                    snap.data!,
                    fit: BoxFit.cover,
                    cacheWidth: cacheW,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (c, e, st) => _placeholder(
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
