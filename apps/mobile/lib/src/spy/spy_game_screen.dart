import 'dart:async';

import 'package:flutter/material.dart';
import 'package:partybox_game_core/partybox_game_core.dart';

import 'local_session_adapter.dart';
import 'spy_controller.dart';

class SpyGameScreen extends StatefulWidget {
  const SpyGameScreen({super.key, this.adapter, this.now});

  final LocalSessionAdapter? adapter;
  final DateTime Function()? now;

  @override
  State<SpyGameScreen> createState() => _SpyGameScreenState();
}

class _SpyGameScreenState extends State<SpyGameScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _names = List.generate(12, (_) => TextEditingController());
  SpyController? _controller;
  Timer? _timer;
  bool _loadFailed = false;
  bool _loading = false;
  bool _settings = false;
  bool _allowExit = false;
  bool _exitPending = false;
  int _count = 4;
  int _minutes = 5;
  String? _suspectId;

  bool get _active =>
      _controller?.phase != null && _controller?.phase != SpyPhase.results;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final adapter =
          widget.adapter ?? LocalSessionAdapter(pack: await SpyPack.load());
      if (!mounted) return;
      final controller = SpyController(adapter: adapter, now: widget.now);
      controller.setForeground(
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      );
      controller.addListener(_refresh);
      setState(() => _controller = controller);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (controller.phase == SpyPhase.discussion) controller.tick();
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      _loading = false;
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller?.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    for (final name in _names) {
      name.dispose();
    }
    super.dispose();
  }

  Future<void> _exit() async {
    if (_exitPending) return;
    if (!_active) {
      Navigator.of(context).pop();
      return;
    }
    _exitPending = true;
    _controller!.conceal();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить партию?'),
        content: const Text('Текущая партия будет потеряна.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Продолжить игру'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    _exitPending = false;
    if (leave != true || !mounted) return;
    setState(() => _allowExit = true);
    // Let PopScope receive the new canPop value before popping the route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_active || _allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Шпион'),
        leading: BackButton(onPressed: _exit),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: ValueKey((
                _controller?.phase,
                _settings,
                _controller?.currentPlayer?.id,
              )),
              padding: const EdgeInsets.all(24),
              children: _content(context),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _content(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return [
        if (_loadFailed) ...[
          const Text('Не удалось загрузить набор. Попробуйте ещё раз.'),
          FilledButton(
            onPressed: _load,
            child: const Text('Повторить загрузку'),
          ),
        ] else
          const Center(child: CircularProgressIndicator()),
      ];
    }
    switch (controller.phase) {
      case null:
        return _settings ? _settingsContent(controller) : _playersContent();
      case SpyPhase.distribution:
        final player = controller.currentPlayer!;
        final card = controller.visibleCard;
        return [
          Text(
            'Карточка ${controller.distributedCount + 1} из ${controller.players.length}',
          ),
          const SizedBox(height: 24),
          _heading(context, 'Передайте телефон: ${player.name}'),
          const SizedBox(height: 24),
          if (card == null) ...[
            const Text('Убедитесь, что только вы смотрите на экран.'),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('reveal-role'),
              onPressed: () => controller.reveal(player.id),
              child: const Text('Показать мою роль'),
            ),
          ] else ...[
            Semantics(
              liveRegion: true,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading(
                        context,
                        card.role == SpyRole.spy
                            ? 'Вы — шпион'
                            : 'Вы — мирный игрок',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        card.location ??
                            'Вы не знаете локацию. Слушайте вопросы и не выдавайте себя.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('handoff-role'),
              onPressed: () => controller.handoff(player.id),
              child: const Text('Скрыть и передать'),
            ),
          ],
        ];
      case SpyPhase.discussion:
        final seconds = controller.remainingSeconds;
        return [
          _heading(context, 'Обсуждение'),
          const SizedBox(height: 24),
          Semantics(
            label: 'Осталось ${seconds ~/ 60} минут ${seconds % 60} секунд',
            child: ExcludeSemantics(
              child: Text(
                '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                key: const ValueKey('discussion-timer'),
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Задавайте друг другу вопросы о месте. Не называйте локацию прямо.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: controller.startVoting,
            child: const Text('Завершить обсуждение'),
          ),
        ];
      case SpyPhase.voting:
        return [
          _heading(context, 'Кого подозревает компания?'),
          const SizedBox(height: 16),
          const Text(
            'Проголосуйте вслух. При ничьей обсудите ещё раз. Ведущий вводит общий выбор.',
          ),
          const SizedBox(height: 16),
          RadioGroup<String>(
            groupValue: _suspectId,
            onChanged: (value) => setState(() => _suspectId = value),
            child: Column(
              children: [
                for (var i = 0; i < controller.players.length; i++)
                  RadioListTile<String>(
                    title: Text(controller.players[i].name),
                    subtitle: Text('Игрок ${i + 1}'),
                    value: controller.players[i].id,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _suspectId == null
                ? null
                : () => controller.accuse(_suspectId!),
            child: const Text('Подтвердить и раскрыть'),
          ),
        ];
      case SpyPhase.results:
        final result = controller.result!;
        final spy = controller.players.singleWhere(
          (p) => p.id == result['spyId'],
        );
        final suspect = controller.players.singleWhere(
          (p) => p.id == result['suspectId'],
        );
        return [
          _heading(
            context,
            result['winner'] == 'civilians'
                ? 'Шпион найден!'
                : 'Шпион победил!',
          ),
          const SizedBox(height: 24),
          Text('Шпион: ${spy.name}'),
          Text('Локация: ${result['location']}'),
          Text('Вы выбрали: ${suspect.name}'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              _suspectId = null;
              controller.replay();
            },
            child: const Text('Ещё раз с теми же игроками'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('В каталог'),
          ),
        ];
    }
  }

  Widget _heading(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.headlineMedium);

  List<Widget> _playersContent() => [
    _heading(context, 'Кто играет?'),
    const SizedBox(height: 16),
    const Text('От 4 до 12 человек. Одинаковые имена допустимы.'),
    const SizedBox(height: 24),
    DropdownButtonFormField<int>(
      isExpanded: true,
      key: const ValueKey('player-count'),
      initialValue: _count,
      decoration: const InputDecoration(labelText: 'Количество игроков'),
      items: [
        for (var count = 4; count <= 12; count++)
          DropdownMenuItem(value: count, child: Text('$count')),
      ],
      onChanged: (value) => setState(() => _count = value!),
    ),
    const SizedBox(height: 16),
    Form(
      key: _formKey,
      child: Column(
        children: [
          for (var i = 0; i < _count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                key: ValueKey('player-name-$i'),
                controller: _names[i],
                decoration: InputDecoration(labelText: 'Игрок ${i + 1}'),
                textCapitalization: TextCapitalization.words,
                textInputAction: i == _count - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите имя'
                    : null,
              ),
            ),
        ],
      ),
    ),
    FilledButton(
      onPressed: () {
        if (!_formKey.currentState!.validate()) return;
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _settings = true);
      },
      child: const Text('К настройкам'),
    ),
    TextButton(onPressed: _exit, child: const Text('Отменить подготовку')),
  ];

  List<Widget> _settingsContent(SpyController controller) => [
    _heading(context, 'Настройки партии'),
    const SizedBox(height: 24),
    DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: controller.adapter.pack.id,
      decoration: const InputDecoration(labelText: 'Набор локаций'),
      items: [
        DropdownMenuItem(
          value: controller.adapter.pack.id,
          child: Text(controller.adapter.pack.title),
        ),
      ],
      onChanged: (_) {},
    ),
    const SizedBox(height: 24),
    DropdownButtonFormField<int>(
      isExpanded: true,
      key: const ValueKey('discussion-duration'),
      initialValue: _minutes,
      decoration: const InputDecoration(labelText: 'Обсуждение, минут'),
      items: [
        for (var minutes = 3; minutes <= 15; minutes++)
          DropdownMenuItem(value: minutes, child: Text('$minutes')),
      ],
      onChanged: (value) => setState(() => _minutes = value!),
    ),
    const SizedBox(height: 24),
    Text('Игроков: $_count · один шпион'),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: () => controller.start([
        for (final name in _names.take(_count)) name.text,
      ], Duration(minutes: _minutes)),
      child: const Text('Раздать роли'),
    ),
    TextButton(
      onPressed: () => setState(() => _settings = false),
      child: const Text('Изменить имена'),
    ),
    TextButton(onPressed: _exit, child: const Text('Отменить подготовку')),
  ];
}
