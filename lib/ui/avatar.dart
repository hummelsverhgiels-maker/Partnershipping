import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/media_service.dart';
import 'theme.dart';

/// Милые аватарки на выбор.
const kAvatarEmojis = <String>[
  '🐱',
  '🐶',
  '🐰',
  '🐻',
  '🐼',
  '🦊',
  '🐨',
  '🐯',
  '🐸',
  '🐵',
  '🦄',
  '🐥',
  '🐙',
  '🦋',
  '🐢',
  '🦦',
  '🍓',
  '🍑',
  '🌸',
  '🌈',
  '⭐',
  '💖',
  '🍩',
  '🧸',
];

/// Аватарка участника: картинка на выбор, своё фото или первая буква имени.
class Avatar extends StatelessWidget {
  final AppStore store;
  final String? memberId;
  final double size;
  const Avatar({
    super.key,
    required this.store,
    required this.memberId,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final m = store.memberById(memberId);
    final value = memberId == null ? '' : store.avatarOf(memberId!);
    return AvatarView(
      value: value,
      color: m?.color ?? kMemberColors.first,
      name: m?.name ?? '?',
      size: size,
    );
  }
}

/// То же, но по готовому значению (для предпросмотра при выборе).
class AvatarView extends StatelessWidget {
  final String value;
  final int color;
  final String name;
  final double size;
  const AvatarView({
    super.key,
    required this.value,
    required this.color,
    required this.name,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Color(color);
    Widget child;
    if (value.startsWith('photo:')) {
      child = _PhotoAvatar(
        path: value.substring(6),
        size: size,
        fallback: _letter(),
      );
    } else if (value.startsWith('emoji:')) {
      child = Center(
        child: Text(
          value.substring(6),
          style: TextStyle(fontSize: size * 0.56),
        ),
      );
    } else {
      child = _letter();
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: kSurface, width: size > 30 ? 2 : 1.5),
      ),
      child: child,
    );
  }

  Widget _letter() => Center(
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: TextStyle(
        fontSize: size * 0.42,
        fontWeight: FontWeight.w900,
        color: kOnPastel,
      ),
    ),
  );
}

class _PhotoAvatar extends StatefulWidget {
  final String path;
  final double size;
  final Widget fallback;
  const _PhotoAvatar({
    required this.path,
    required this.size,
    required this.fallback,
  });

  @override
  State<_PhotoAvatar> createState() => _PhotoAvatarState();
}

class _PhotoAvatarState extends State<_PhotoAvatar> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = MediaService.bytes(widget.path);
  }

  @override
  void didUpdateWidget(covariant _PhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _future = MediaService.bytes(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final px = (widget.size * dpr).round().clamp(48, 400);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return widget.fallback;
        return Image.memory(
          snap.data!,
          fit: BoxFit.cover,
          cacheWidth: px,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (c, e, s) => widget.fallback,
        );
      },
    );
  }
}
