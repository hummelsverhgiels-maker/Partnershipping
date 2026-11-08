import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../logic/mood.dart';
import '../models.dart';
import 'common.dart';
import 'theme.dart';

const _moodColors = [
  Color(0xFFF4A6A6),
  Color(0xFFF8C79A),
  Color(0xFFF8E0A0),
  Color(0xFFBFE3B0),
  Color(0xFF9ED9B5),
];

/// Индикатор настроения: свой ползунок и настроение партнёра.
class MoodCard extends StatefulWidget {
  final AppStore store;
  const MoodCard({super.key, required this.store});

  @override
  State<MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<MoodCard> {
  double? _drag; // значение во время перетаскивания

  AppStore get s => widget.store;

  String _ago(int? ms) {
    if (ms == null) return '';
    final d = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (d.inMinutes < 2) return 'только что';
    if (d.inMinutes < 60) return '${d.inMinutes} мин назад';
    if (d.inHours < 24) return '${d.inHours} ч назад';
    return '${d.inDays} дн назад';
  }

  @override
  Widget build(BuildContext context) {
    final me = s.me;
    final partner = s.partner;
    final saved = me == null ? null : s.moodOf(me.id);
    final value = _drag ?? (saved?.toDouble() ?? 60);
    final v = value.round();
    final isSet = saved != null || _drag != null;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isSet ? moodEmoji(v) : '🙂',
                style: const TextStyle(fontSize: 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSet ? moodLabel(v) : 'Как настроение?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      isSet
                          ? 'Моё настроение · $v%'
                          : 'Подвиньте ползунок, партнёр увидит',
                      style: TextStyle(fontSize: 12.5, color: kInkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MoodSlider(
            value: value,
            onChanged: (x) {
              final before = _drag?.round() ?? saved ?? -1;
              if (moodEmoji(x.round()) !=
                  (before < 0 ? '' : moodEmoji(before))) {
                HapticFeedback.selectionClick();
              }
              setState(() => _drag = x);
            },
            onEnd: (x) {
              s.setMood(x.round());
              setState(() => _drag = null);
            },
          ),
          if (partner != null) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: kLine),
            const SizedBox(height: 12),
            _partnerRow(partner),
          ],
        ],
      ),
    );
  }

  Widget _partnerRow(Member partner) {
    final pv = s.moodOf(partner.id);
    final ts = s.moods[partner.id]?.i('ts');
    return Row(
      children: [
        ColorDot(partner.color, size: 12),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            partner.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (pv == null)
          Text(
            'пока не отметил(а)',
            style: TextStyle(color: kInkSoft, fontSize: 13),
          )
        else ...[
          Text(moodEmoji(pv), style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          SizedBox(
            width: 74,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 8,
                color: kField,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (pv / 100).clamp(0.02, 1.0),
                  child: Container(
                    color: _moodColors[(pv / 25).floor().clamp(0, 4)],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$pv%', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
        if (pv != null && ts != null) ...[const SizedBox(width: 6)],
      ],
    ).withCaption(_ago(ts), pv != null);
  }
}

extension _Caption on Widget {
  Widget withCaption(String text, bool show) {
    if (!show || text.isEmpty) return this;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        this,
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 20),
          child: Text(
            'обновлено $text',
            style: TextStyle(fontSize: 11.5, color: kInkSoft),
          ),
        ),
      ],
    );
  }
}

/// Ползунок с цветной дорожкой и смайликом на ручке.
class _MoodSlider extends StatelessWidget {
  final double value; // 0..100
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;
  const _MoodSlider({
    required this.value,
    required this.onChanged,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    const thumb = 46.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final usable = (w - thumb).clamp(1.0, 10000.0);
        double toValue(double dx) =>
            (((dx - thumb / 2) / usable) * 100).clamp(0.0, 100.0);
        final left = usable * (value / 100);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => onChanged(toValue(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => onChanged(toValue(d.localPosition.dx)),
          onHorizontalDragEnd: (_) => onEnd(value),
          onTapDown: (d) => onChanged(toValue(d.localPosition.dx)),
          onTapUp: (_) => onEnd(value),
          child: SizedBox(
            height: thumb + 6,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(colors: _moodColors),
                  ),
                ),
                Positioned(
                  left: left,
                  child: Container(
                    width: thumb,
                    height: thumb,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBorder, width: 1.5),
                    ),
                    child: Text(
                      moodEmoji(value.round()),
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
