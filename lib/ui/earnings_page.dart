import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../logic/stats.dart';
import '../models.dart';
import '../util.dart';
import 'common.dart';
import 'theme.dart';

/// Часы и заработок за месяц.
class EarningsPage extends StatefulWidget {
  final AppStore store;
  const EarningsPage({super.key, required this.store});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  late DateTime _month;

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _shift(int d) =>
      setState(() => _month = DateTime(_month.year, _month.month + d));

  Future<void> _editRate() async {
    final me = s.session!.memberId;
    final cur = s.hourRateFor(me);
    final ctrl = TextEditingController(
      text: cur == 0
          ? ''
          : cur.toStringAsFixed(cur == cur.roundToDouble() ? 0 : 2),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ставка за час'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            hintText: 'Например: 350',
            suffixText: '₽ / час',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    final text = ctrl.text.replaceAll(',', '.');
    ctrl.dispose();
    if (ok == true) {
      s.setHourRate(me, double.tryParse(text) ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final me = s.me;
        final partner = s.partner;
        final today = dateOnly(DateTime.now());
        final rate = me == null ? 0.0 : s.hourRateFor(me.id);
        final mine = me == null
            ? null
            : monthStats(s.schedule, me.id, _month.year, _month.month, rate);

        // накоплено с последней выплаты
        PeriodStats? accrued;
        DateTime? lastPay;
        if (me != null && rate > 0) {
          final pays = s.schedule.paymentsInRange(
            addDays(today, -62),
            today,
            memberId: me.id,
          );
          if (pays.isNotEmpty) {
            lastPay = pays.last.date;
            accrued = periodStats(
              s.schedule,
              me.id,
              addDays(lastPay, 1),
              today,
              rate,
            );
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Заработок'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Row(
                children: [
                  _arrow(Icons.chevron_left_rounded, () => _shift(-1)),
                  Expanded(
                    child: Center(
                      child: Text(
                        monthTitle(_month),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  _arrow(Icons.chevron_right_rounded, () => _shift(1)),
                ],
              ),
              const SizedBox(height: 12),
              if (me != null && mine != null)
                _card(me, mine, rate, mineCard: true),
              if (partner != null) ...[
                const SizedBox(height: 12),
                _card(
                  partner,
                  monthStats(
                    s.schedule,
                    partner.id,
                    _month.year,
                    _month.month,
                    0,
                  ),
                  0,
                  mineCard: false,
                ),
              ],
              if (accrued != null && lastPay != null) ...[
                const SectionTitle('С ПОСЛЕДНЕЙ ВЫПЛАТЫ'),
                SoftCard(
                  color: kWarnBg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmtMoney(accrued.earnings),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'за ${accrued.shifts} ${plural(accrued.shifts, 'смену', 'смены', 'смен')}'
                        ' · ${fmtHours(accrued.hours)}'
                        ' (с ${lastPay.day}.${lastPay.month.toString().padLeft(2, '0')})',
                        style: TextStyle(color: kInkSoft),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Часы считаются по дню начала смены, ночные смены учитываются целиком. '
                'Ночными считаются часы с 22:00 до 06:00. Налоги и надбавки не учитываются.',
                style: TextStyle(color: kInkSoft, fontSize: 12.5, height: 1.35),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => PressScale(
    scale: 0.88,
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kSurface,
        shape: BoxShape.circle,
        border: Border.all(color: kLine),
      ),
      child: Icon(icon, size: 28),
    ),
  );

  Widget _card(
    Member m,
    PeriodStats st,
    double rate, {
    required bool mineCard,
  }) {
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: kInkSoft)),
        ],
      ),
    );
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColorDot(m.color, size: 14),
              const SizedBox(width: 8),
              Text(
                mineCard ? 'Я (${m.name})' : m.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('${st.shifts}', 'смен'),
              stat(fmtHours(st.hours), 'всего'),
              stat(fmtHours(st.nightHours), 'ночных'),
            ],
          ),
          if (mineCard) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAccentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rate > 0 ? fmtMoney(st.earnings) : 'Ставка не задана',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          rate > 0
                              ? 'примерный заработок · ${fmtMoney(rate)}/ч'
                              : 'Задайте ставку, чтобы видеть заработок',
                          style: TextStyle(fontSize: 12.5, color: kInkSoft),
                        ),
                      ],
                    ),
                  ),
                  Bouncy(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: _editRate,
                      child: Text(rate > 0 ? 'Изменить' : 'Задать'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
