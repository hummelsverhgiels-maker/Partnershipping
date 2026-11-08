import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../data/backend.dart';
import '../data/store.dart';
import '../models.dart';
import 'common.dart';
import 'theme.dart';

/// Первый запуск: имя и цвет, затем создать пару или войти по коду.
class OnboardingScreen extends StatefulWidget {
  final AppStore store;
  const OnboardingScreen({super.key, required this.store});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  int _color = kMemberColors[1];
  int _step = 0; // 0 имя, 1 выбор, 2 вход по коду
  bool _busy = false;
  String? _error;
  String? _raw;
  ({String pairId, List<Member> members})? _found;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
      _raw = null;
    });
    try {
      await job();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = Backend.explain(e);
          _raw = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() => _run(() async {
    await widget.store.createPair(_name.text.trim(), _color);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Пара создана!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Отправьте этот код партнёру. Он вводит его на своём телефоне.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.store.session!.code,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Код всегда можно посмотреть в «Настройках».',
              textAlign: TextAlign.center,
              style: TextStyle(color: kInkSoft),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(
              ClipboardData(text: widget.store.session!.code),
            ),
            child: const Text('Скопировать'),
          ),
          Bouncy(
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Дальше'),
            ),
          ),
        ],
      ),
    );
  });

  Future<void> _find() => _run(() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 4) throw 'Введите код целиком';
    final r = await Backend.findPair(code);
    if (r == null) throw 'pair_not_found';
    setState(() => _found = r);
  });

  Future<void> _join() => _run(() async {
    await widget.store.joinPair(
      _code.text.trim().toUpperCase(),
      _name.text.trim(),
      _color,
    );
  });

  Future<void> _claim(Member m) => _run(() async {
    await widget.store.claimMember(_code.text.trim().toUpperCase(), m);
  });

  Future<void> _local() => _run(() async {
    await widget.store.startLocal(_name.text.trim(), _color);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: const Text('💞', style: TextStyle(fontSize: 64)),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'V&V loving planning',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Смены, выходные, зарплата, дела и покупки',
                style: TextStyle(color: kInkSoft),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey('$_step-${_found != null}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step == 0) ..._nameStep(),
                    if (_step == 1) ..._chooseStep(),
                    if (_step == 2) ..._codeStep(),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              SoftCard(
                color: const Color(0xFFFFE3E0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: const TextStyle(color: kInk)),
                    if (_raw != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Подробности: ${_raw!.length > 220 ? _raw!.substring(0, 220) : _raw}',
                          style: const TextStyle(fontSize: 11, color: kInkSoft),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Версия $kBuild · сервер: ${Backend.activeUrl == kSupabaseUrl ? 'напрямую' : 'через посредника'}',
                style: const TextStyle(fontSize: 11, color: kInkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _nameStep() => [
    SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Как вас зовут?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Ваше имя'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ваш цвет в календаре',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ColorPicker(
            selected: _color,
            onChanged: (c) => setState(() => _color = c),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    Bouncy(
      child: FilledButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => setState(() => _step = 1),
        child: const Text('Дальше'),
      ),
    ),
  ];

  List<Widget> _chooseStep() => [
    if (!Backend.configured)
      const SoftCard(
        color: Color(0xFFFFF1D6),
        child: Text(
          'Сервер синхронизации ещё не подключён, поэтому пару создать нельзя. '
          'Пока можно пользоваться приложением только на этом телефоне.',
        ),
      ),
    const SizedBox(height: 12),
    if (Backend.configured) ...[
      Bouncy(
        child: FilledButton.icon(
          onPressed: _busy ? null : _create,
          icon: const Icon(Icons.favorite_outline),
          label: const Text('Создать пару'),
        ),
      ),
      const SizedBox(height: 12),
      Bouncy(
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => setState(() => _step = 2),
          icon: const Icon(Icons.vpn_key_outlined),
          label: const Text('У меня есть код'),
        ),
      ),
    ] else
      Bouncy(
        child: FilledButton(
          onPressed: _busy ? null : _local,
          child: const Text('Пользоваться без пары'),
        ),
      ),
    const SizedBox(height: 12),
    TextButton(
      onPressed: _busy ? null : () => setState(() => _step = 0),
      child: const Text('Назад'),
    ),
    if (_busy) const Center(child: CircularProgressIndicator()),
    if (Backend.configured) ...[
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : _local,
        child: const Text('Пока без пары, только на этом телефоне'),
      ),
    ],
  ];

  List<Widget> _codeStep() => [
    SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Код пары',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Введите код, который показан в приложении у партнёра. '
            'Также так можно вернуться в пару после переустановки.',
            style: TextStyle(color: kInkSoft),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 5,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(counterText: '', hintText: 'КОД'),
            onChanged: (_) => setState(() => _found = null),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    if (_found == null)
      Bouncy(
        child: FilledButton(
          onPressed: _busy ? null : _find,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Найти пару'),
        ),
      )
    else
      ..._foundList(),
    const SizedBox(height: 8),
    TextButton(
      onPressed: _busy ? null : () => setState(() => _step = 1),
      child: const Text('Назад'),
    ),
  ];

  Future<void> _confirmClaim(Member m) async {
    final ok = await confirm(
      context,
      'Вы точно «${m.name}»?\n\n'
      'Выбирайте это, только если вы уже были в паре под этим именем '
      'и переустановили приложение. Если вы другой человек, '
      'у «${m.name}» пропадёт доступ.',
      yes: 'Да, это я',
      no: 'Нет',
    );
    if (ok) await _claim(m);
  }

  List<Widget> _foundList() {
    final f = _found!;
    final canJoin = f.members.length < 2;
    return [
      if (canJoin) ...[
        const SectionTitle('Вы подключаетесь к паре впервые?'),
        Bouncy(
          child: FilledButton(
            onPressed: _busy ? null : _join,
            child: Text('Я новый участник: ${_name.text.trim()}'),
          ),
        ),
        const SizedBox(height: 6),
      ] else
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'В паре уже двое. Если вы переустановили приложение, выберите себя ниже.',
            style: TextStyle(color: kInkSoft),
          ),
        ),
      const SectionTitle(
        'ИЛИ: Я уже был(а) в паре и переустановил(а) приложение',
      ),
      for (final m in f.members) ...[
        SoftCard(
          onTap: _busy ? null : () => _confirmClaim(m),
          child: Row(
            children: [
              ColorDot(m.color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Вернуться как «${m.name}»',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}
