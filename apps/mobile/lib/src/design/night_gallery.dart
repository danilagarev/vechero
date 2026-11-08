import 'package:flutter/material.dart';

import 'night_art.dart';
import 'night_components.dart';
import 'night_result_art.dart';

/// Opt-in development entry: --dart-define=DESIGN_GALLERY=true (non-release).
class NightGallery extends StatelessWidget {
  const NightGallery({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ПОЛНОЧНЫЙ КЛУБ')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const NightEyebrow('ГАЛЕРЕЯ КОМПОНЕНТОВ / PB-015'),
              const SizedBox(height: 24),
              Text(
                'Хороший вечер.\nПлохое алиби.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 24),
              const NightPanel(accent: true, child: NightArt()),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NightBadge('4–12 игроков'),
                  NightBadge('Один шпион'),
                ],
              ),
              const SizedBox(height: 16),
              NightButton(label: 'Основное действие', onPressed: () {}),
              const SizedBox(height: 12),
              const NightButton(
                label: 'Сначала выберите игрока',
                onPressed: null,
              ),
              const SizedBox(height: 16),
              const TextField(
                key: ValueKey('gallery-name'),
                decoration: InputDecoration(
                  labelText: 'Имя игрока',
                  hintText: 'Александра',
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Имя игрока',
                  errorText: 'Введите имя',
                ),
              ),
              const SizedBox(height: 16),
              const NightPanel(
                child: Column(
                  children: [
                    NightArt(kind: NightArtKind.seal, height: 100),
                    Text('Ваша роль под защитой'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _MotionPreview(),
              const SizedBox(height: 16),
              const LinearProgressIndicator(
                value: .4,
                semanticsLabel: 'Осталось 40 процентов времени',
              ),
              const SizedBox(height: 16),
              NightButton(
                label: 'Диалог выхода',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    scrollable: true,
                    title: const Text('Завершить партию?'),
                    content: const Text('Текущая партия будет потеряна.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Продолжить игру'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MotionPreview extends StatefulWidget {
  const _MotionPreview();
  @override
  State<_MotionPreview> createState() => _MotionPreviewState();
}

class _MotionPreviewState extends State<_MotionPreview> {
  int _replay = 0;
  bool _reduce = false;
  @override
  Widget build(BuildContext context) => NightPanel(
    child: Column(
      children: [
        const NightEyebrow('ДВИЖЕНИЕ / РЕЗУЛЬТАТ'),
        MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations:
                _reduce || MediaQuery.disableAnimationsOf(context),
          ),
          child: NightResultArt(
            key: ValueKey(_replay),
            kind: NightArtKind.seal,
            height: 140,
          ),
        ),
        SwitchListTile(
          title: const Text('Уменьшить движение'),
          value: _reduce,
          onChanged: (value) => setState(() => _reduce = value),
          contentPadding: EdgeInsets.zero,
        ),
        NightButton(
          label: 'Повторить анимацию результата',
          onPressed: () => setState(() => _replay++),
        ),
      ],
    ),
  );
}
