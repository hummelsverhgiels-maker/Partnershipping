import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/backend.dart';
import '../data/store.dart';
import '../services/media_service.dart';
import 'avatar.dart';
import 'common.dart';
import 'theme.dart';

/// Выбор аватарки: милая картинка или своё фото.
Future<void> showAvatarSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AvatarSheet(store: store),
  );
}

class _AvatarSheet extends StatefulWidget {
  final AppStore store;
  const _AvatarSheet({required this.store});

  @override
  State<_AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends State<_AvatarSheet> {
  bool _busy = false;

  AppStore get s => widget.store;

  Future<void> _photo(ImageSource source) async {
    if (s.isLocal) {
      toast(context, 'Своё фото работает только в паре с сервером');
      return;
    }
    try {
      final m = await MediaService.pickImage(source, maxSide: 512, quality: 85);
      if (m == null || !mounted) return;
      setState(() => _busy = true);
      final path = await MediaService.upload(s.session!, m, folder: 'avatars');
      s.setAvatar('photo:$path');
      if (mounted) toast(context, 'Аватарка обновлена');
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Не удалось загрузить фото'),
            content: SingleChildScrollView(
              child: SelectableText(
                '${e is String ? e : Backend.explain(e)}\n\nПодробности: $e',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final me = s.me;
        final current = me == null ? '' : s.avatarOf(me.id);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Аватарка',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AvatarView(
                          value: current,
                          color: me?.color ?? kMemberColors.first,
                          name: me?.name ?? '?',
                          size: 110,
                        ),
                        if (_busy)
                          const SizedBox(
                            width: 110,
                            height: 110,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Bouncy(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _photo(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Моё фото'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Bouncy(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _photo(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Снимок'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SectionTitle('Или выберите картинку'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (final e in kAvatarEmojis)
                        PressScale(
                          scale: 0.88,
                          onTap: _busy ? null : () => s.setAvatar('emoji:$e'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: current == 'emoji:$e'
                                  ? kAccentSoft
                                  : kField,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: current == 'emoji:$e'
                                    ? kAccentDeep
                                    : kBorder,
                                width: current == 'emoji:$e' ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (current.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : () => s.setAvatar(''),
                        child: const Text('Убрать аватарку'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
