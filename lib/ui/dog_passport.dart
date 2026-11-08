import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/backend.dart';
import '../data/store.dart';
import '../logic/dog.dart';
import '../services/media_service.dart';
import '../util.dart';
import 'common.dart';
import 'media_widgets.dart';
import 'theme.dart';

const _kDogEmojis = ['🐶', '🐕', '🦮', '🐕‍🦺', '🐩', '🐾', '🦴', '🐺'];

/// 5) «Паспорт собаки»: всё важное в одном месте — кличка, порода, чип,
/// ветеринар (звонок в одно касание), аллергии, корм и режим.
class DogPassportPage extends StatefulWidget {
  final AppStore store;
  const DogPassportPage({super.key, required this.store});

  @override
  State<DogPassportPage> createState() => _DogPassportPageState();
}

class _DogPassportPageState extends State<DogPassportPage> {
  final _c = <String, TextEditingController>{};
  late String _emoji;
  String? _photo;
  String? _sex;
  String? _birthday;
  late int _walks;
  late int _meals;
  late int _aloneMax;
  late int _commute;
  bool _dirty = false;
  bool _uploading = false;

  static const _fields = [
    'name',
    'breed',
    'chip',
    'vet',
    'vetPhone',
    'vetAddr',
    'allergies',
    'food',
    'notes',
  ];

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    final d = s.dog;
    for (final f in _fields) {
      _c[f] = TextEditingController(text: d?.s(f) ?? '')
        ..addListener(() => _dirty = true);
    }
    _c['vetPhone']!.addListener(() {
      if (mounted) setState(() {});
    });
    _emoji = s.dogEmoji;
    _photo = d?.s('photo');
    _sex = d?.s('sex');
    _birthday = d?.s('birthday');
    _walks = s.dogWalks;
    _meals = s.dogMeals;
    _aloneMax = s.dogAloneMax;
    _commute = s.dogCommute;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save({bool quiet = false}) {
    s.saveDog({
      for (final f in _fields) f: _c[f]!.text.trim(),
      'emoji': _emoji,
      'photo': _photo,
      'sex': _sex,
      'birthday': _birthday,
      'walks': _walks,
      'meals': _meals,
      'aloneMax': _aloneMax,
      'commute': _commute,
    });
    _dirty = false;
    if (!quiet) toast(context, 'Паспорт сохранён 🐾');
  }

  void _set(VoidCallback f) => setState(() {
    f();
    _dirty = true;
  });

  Future<void> _pickPhoto() async {
    if (s.isLocal) {
      toast(context, 'Фото работают только в паре с сервером');
      return;
    }
    try {
      final m = await MediaService.pickImage(
        ImageSource.gallery,
        maxSide: 900,
        quality: 78,
      );
      if (m == null) return;
      setState(() => _uploading = true);
      final path = await MediaService.upload(s.session!, m, folder: 'dog');
      _set(() => _photo = path);
      _save(quiet: true);
    } catch (e) {
      if (mounted) {
        toast(context, 'Не удалось загрузить фото: ${Backend.explain(e)}');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    TextInputType? type,
    int lines = 1,
    Widget? suffix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _c[key],
      keyboardType: type,
      minLines: 1,
      maxLines: lines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, suffixIcon: suffix),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final birth = _birthday == null || _birthday!.isEmpty
        ? null
        : parseYmd(_birthday!);
    final phone = _c['vetPhone']!.text.trim();
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _dirty) _save(quiet: true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Паспорт собаки'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Сохранить')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _uploading ? null : _pickPhoto,
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: kAccentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: kCardBorder, width: 3),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: _uploading
                          ? const CircularProgressIndicator()
                          : (_photo != null && _photo!.isNotEmpty
                                ? ImageThumb(
                                    path: _photo!,
                                    width: 112,
                                    height: 112,
                                    onTap: _pickPhoto,
                                  )
                                : Text(
                                    _emoji,
                                    style: const TextStyle(fontSize: 56),
                                  )),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: kAccentDeep,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploading ? null : _pickPhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_photo != null)
              Center(
                child: TextButton(
                  onPressed: () => _set(() => _photo = null),
                  child: const Text('Убрать фото'),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _kDogEmojis)
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 20)),
                    selected: _emoji == e,
                    onSelected: (_) => _set(() => _emoji = e),
                  ),
              ],
            ),
            const SectionTitle('О СОБАКЕ'),
            _field('name', 'Кличка'),
            _field('breed', 'Порода'),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Мальчик'),
                  selected: _sex == 'm',
                  onSelected: (_) => _set(() => _sex = 'm'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Девочка'),
                  selected: _sex == 'f',
                  onSelected: (_) => _set(() => _sex = 'f'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Bouncy(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final d = await pickDate(
                    context,
                    birth ?? DateTime(today.year - 1, today.month, today.day),
                  );
                  if (d != null) _set(() => _birthday = ymd(dateOnly(d)));
                },
                icon: const Icon(Icons.cake_outlined),
                label: Text(
                  birth == null
                      ? 'День рождения'
                      : '${birth.day}.${birth.month.toString().padLeft(2, '0')}.${birth.year}'
                            ' · ${dogAge(birth, today)}',
                ),
              ),
            ),
            const SizedBox(height: 10),
            _field('chip', 'Номер чипа / клейма', type: TextInputType.text),
            if (s.dogWeightNow != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Вес: ${s.dogWeightNow} кг (меняется в «Здоровье»)',
                  style: TextStyle(color: kInkSoft),
                ),
              ),
            const SectionTitle('ВЕТЕРИНАР'),
            _field('vet', 'Клиника и врач'),
            _field(
              'vetPhone',
              'Телефон',
              type: TextInputType.phone,
              suffix: phone.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Позвонить',
                      icon: const Icon(Icons.call_rounded),
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}',
                        ),
                      ),
                    ),
            ),
            _field('vetAddr', 'Адрес клиники'),
            const SectionTitle('ПИТАНИЕ И ОСОБЕННОСТИ'),
            _field('food', 'Корм и порция (например, 2 × 150 г)', lines: 3),
            _field('allergies', 'Аллергии, лекарства, запреты', lines: 3),
            _field('notes', 'Заметки (команды, страхи, привычки)', lines: 4),
            const SectionTitle('РЕЖИМ'),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Прогулок в день',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in [2, 3])
                        ChoiceChip(
                          label: Text('$n'),
                          selected: _walks == n,
                          onSelected: (_) => _set(() => _walks = n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Кормлений в день',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in [1, 2, 3])
                        ChoiceChip(
                          label: Text('$n'),
                          selected: _meals == n,
                          onSelected: (_) => _set(() => _meals = n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Может побыть одна до $_aloneMax ч',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: _aloneMax.toDouble(),
                    min: 2,
                    max: 16,
                    divisions: 14,
                    label: '$_aloneMax ч',
                    onChanged: (v) => _set(() => _aloneMax = v.round()),
                  ),
                  Text(
                    'Дорога до работы: $_commute мин',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: _commute.toDouble(),
                    min: 0,
                    max: 120,
                    divisions: 12,
                    label: '$_commute мин',
                    onChanged: (v) => _set(() => _commute = v.round()),
                  ),
                  Text(
                    'Нужно для подсказок «Кто гуляет» и предупреждения, '
                    'если собака долго одна.',
                    style: TextStyle(color: kInkSoft, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Bouncy(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Сохранить'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
