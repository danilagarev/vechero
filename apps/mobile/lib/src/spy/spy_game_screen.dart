import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:partybox_game_core/partybox_game_core.dart';

import '../design/night_art.dart';
import '../design/night_components.dart';
import '../design/night_theme.dart';
import '../design/night_result_art.dart';

import 'local_session_adapter.dart';
import 'spy_controller.dart';
import '../storage/spy_setup.dart';

class SpyGameScreen extends StatefulWidget {
  const SpyGameScreen({
    super.key,
    this.adapter,
    this.now,
    this.loadPack,
    this.setupStore,
  });

  final LocalSessionAdapter? adapter;
  final DateTime Function()? now;
  final Future<SpyPack> Function()? loadPack;
  final SpySetupStore? setupStore;

  @override
  State<SpyGameScreen> createState() => _SpyGameScreenState();
}

class _SpyGameScreenState extends State<SpyGameScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _names = List.generate(12, (_) => TextEditingController());
  SpyController? _controller;
  Timer? _timer;
  Timer? _handoffCooldown;
  bool _canReveal = true;
  bool _loadFailed = false;
  bool _loading = false;
  bool _settings = false;
  bool _allowExit = false;
  bool _exitPending = false;
  bool _saving = false;
  bool _clearing = false;
  String? _setupNotice;
  int _setupRevision = 0;
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
          widget.adapter ??
          LocalSessionAdapter(pack: await (widget.loadPack ?? SpyPack.load)());
      await _restoreSetup(adapter.pack.id);
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

  Future<void> _restoreSetup(String packId) async {
    final store = widget.setupStore;
    if (store == null) return;
    try {
      final restored = await store.load();
      if (!mounted) return;
      switch (restored.status) {
        case SetupRestoreStatus.empty:
          break;
        case SetupRestoreStatus.restored:
          final setup = restored.setup!;
          _count = setup.names.length;
          _minutes = setup.discussionMinutes;
          for (var i = 0; i < setup.names.length; i++) {
            _names[i].text = setup.names[i];
          }
          _setupNotice = setup.packId == packId
              ? 'Имена и время остались с прошлой игры. Начнём новый раунд.'
              : 'Прежний набор недоступен. Имена и время восстановлены; используем текущий набор.';
        case SetupRestoreStatus.invalid:
        case SetupRestoreStatus.unsupportedVersion:
          _setupNotice =
              'Сохранённые настройки недоступны. Подготовьте новую партию.';
      }
    } catch (_) {
      if (mounted) {
        _setupNotice =
            'Не удалось загрузить настройки. Можно начать новую партию.';
      }
    }
  }

  Future<void> _start(SpyController controller) async {
    if (_saving || _clearing || controller.phase != null) return;
    final setup = SpySetup(
      names: [for (final name in _names.take(_count)) name.text],
      discussionMinutes: _minutes,
      packId: controller.adapter.pack.id,
    );
    setState(() => _saving = true);
    var saved = true;
    try {
      await widget.setupStore?.save(setup);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    controller.start(setup.names, Duration(minutes: setup.discussionMinutes));
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Игра началась, но настройки не сохранились. После закрытия их нужно ввести заново.',
          ),
        ),
      );
    }
  }

  Future<void> _clearSetup() async {
    if (_clearing || _saving) return;
    setState(() => _clearing = true);
    try {
      await widget.setupStore!.clear();
      if (!mounted) return;
      for (final name in _names) {
        name.clear();
      }
      setState(() {
        _count = 4;
        _setupRevision++;
        _minutes = 5;
        _settings = false;
        _setupNotice = 'Сохранённые настройки удалены.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _setupNotice =
              'Не удалось удалить настройки. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
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
    _handoffCooldown?.cancel();
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    for (final name in _names) {
      name.dispose();
    }
    super.dispose();
  }

  void _handoff(String playerId) {
    final controller = _controller!;
    if (controller.currentPlayer?.id != playerId ||
        controller.visibleCard == null) {
      return;
    }
    // A second physical tap must not activate the next player's reveal button.
    _handoffCooldown?.cancel();
    _canReveal = false;
    controller.handoff(playerId);
    _handoffCooldown = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _canReveal = true);
    });
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
        scrollable: true,
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
        title: const Text('ШПИОН'),
        leading: BackButton(onPressed: _exit),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: ValueKey((
                _controller?.phase,
                _settings,
                _controller?.currentPlayer?.id,
                _setupRevision,
              )),
              padding: const EdgeInsets.all(24),
              children: [
                NightEntrance(
                  key: ValueKey((
                    _controller?.phase,
                    _settings,
                    _controller?.currentPlayer?.id,
                    _loadFailed,
                  )),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _content(context),
                  ),
                ),
              ],
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
          const NightArt(kind: NightArtKind.constellation, height: 140),
          _heading(context, 'Набор не загрузился'),
          const SizedBox(height: 16),
          const Text('Не удалось загрузить набор. Попробуйте ещё раз.'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _load,
            child: const Text('Повторить загрузку'),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Загрузка локаций',
              ),
            ),
          ),
      ];
    }
    switch (controller.phase) {
      case null:
        return [
          if (_setupNotice != null) ...[
            NightPanel(child: Text(_setupNotice!)),
            const SizedBox(height: 20),
          ],
          ...(_settings ? _settingsContent(controller) : _playersContent()),
        ];
      case SpyPhase.distribution:
        final player = controller.currentPlayer!;
        final card = controller.visibleCard;
        return [
          NightEyebrow('ЛИЧНАЯ КАРТОЧКА / ТЕЛЕФОН ПО КРУГУ'),
          const SizedBox(height: 12),
          Text(
            'Карточка ${controller.distributedCount + 1} из ${controller.players.length}',
            style: const TextStyle(color: NightColors.muted),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: controller.distributedCount / controller.players.length,
            semanticsLabel:
                'Роли получили ${controller.distributedCount} из ${controller.players.length}',
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 24),
          _heading(context, 'Передайте телефон: ${player.name}'),
          const SizedBox(height: 24),
          if (card == null) ...[
            const NightPanel(
              child: Column(
                children: [
                  NightArt(kind: NightArtKind.seal, height: 150),
                  Text(
                    'Ваша роль под защитой',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Убедитесь, что только вы смотрите на экран.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NightColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            NightButton(
              key: const ValueKey('reveal-role'),
              onPressed: !_canReveal
                  ? null
                  : () {
                      if (_canReveal) controller.reveal(player.id);
                    },
              label: 'Показать мою роль',
            ),
          ] else ...[
            NightEntrance(
              key: ValueKey(('secret', player.id)),
              child: Semantics(
                liveRegion: true,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        NightArt(
                          kind: card.role == SpyRole.spy
                              ? NightArtKind.eye
                              : NightArtKind.constellation,
                          height: 150,
                          onColor: NightColors.accent,
                          color: card.role == SpyRole.spy
                              ? NightColors.raised
                              : NightColors.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          card.role == SpyRole.spy
                              ? 'Вы — шпион'
                              : 'Вы — мирный игрок',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: NightColors.accent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          card.location ??
                              'Вы не знаете локацию. Слушайте вопросы и не выдавайте себя.',
                          textAlign: TextAlign.center,
                          style: card.location == null
                              ? Theme.of(context).textTheme.bodyLarge
                              : Theme.of(context).textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            NightButton(
              key: const ValueKey('handoff-role'),
              onPressed: () => _handoff(player.id),
              label: 'Скрыть и передать',
            ),
          ],
        ];
      case SpyPhase.discussion:
        final seconds = controller.remainingSeconds;
        return [
          const NightEyebrow('ВСЕ РОЛИ РОЗДАНЫ'),
          const SizedBox(height: 16),
          _heading(context, 'Обсуждение'),
          const NightArt(kind: NightArtKind.constellation, height: 130),
          const SizedBox(height: 24),
          Semantics(
            label: 'Осталось ${seconds ~/ 60} минут ${seconds % 60} секунд',
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                  key: const ValueKey('discussion-timer'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 80,
                    height: 1.1,
                    letterSpacing: -4,
                    fontWeight: FontWeight.w800,
                    color: NightColors.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(end: seconds / (_minutes * 60)),
            duration: NightMotion.reduced(context)
                ? Duration.zero
                : NightMotion.enter,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
              semanticsLabel: 'Оставшееся время обсуждения',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Задавайте друг другу вопросы о месте. Не называйте локацию прямо.',
          ),
          const SizedBox(height: 24),
          NightButton(
            onPressed: controller.startVoting,
            label: 'Завершить обсуждение',
          ),
        ];
      case SpyPhase.voting:
        return [
          const NightEyebrow('ГОЛОСОВАНИЕ / ОБЩИЙ ВЫБОР'),
          const SizedBox(height: 16),
          _heading(context, 'Кого подозревает компания?'),
          const SizedBox(height: 16),
          const Text(
            'Проголосуйте вслух. При ничьей обсудите ещё раз. Ведущий вводит общий выбор.',
          ),
          const SizedBox(height: 16),
          RadioGroup<String>(
            groupValue: _suspectId,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _suspectId = value);
            },
            child: Column(
              children: [
                for (var i = 0; i < controller.players.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      animationDuration: NightMotion.reduced(context)
                          ? Duration.zero
                          : NightMotion.quick,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: _suspectId == controller.players[i].id
                              ? NightColors.accent
                              : NightColors.border,
                        ),
                      ),
                      color: _suspectId == controller.players[i].id
                          ? NightColors.raised
                          : NightColors.surface,
                      child: RadioListTile<String>(
                        selected: _suspectId == controller.players[i].id,
                        title: Text(controller.players[i].name),
                        subtitle: Text('Игрок ${i + 1}'),
                        value: controller.players[i].id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_suspectId != null) ...[
            Text(
              'Выбор компании: ${controller.players.firstWhere((p) => p.id == _suspectId).name}',
              style: const TextStyle(color: NightColors.accent),
            ),
            const SizedBox(height: 16),
          ],
          NightButton(
            onPressed: _suspectId == null
                ? null
                : () => controller.accuse(_suspectId!),
            label: 'Подтвердить и раскрыть',
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
          const NightEyebrow('ИТОГ ПАРТИИ'),
          NightResultArt(
            kind: result['winner'] == 'civilians'
                ? NightArtKind.seal
                : NightArtKind.eye,
            height: 180,
            onColor: NightColors.accent,
            color: result['winner'] == 'civilians'
                ? NightColors.accent
                : NightColors.raised,
          ),
          _heading(
            context,
            result['winner'] == 'civilians'
                ? 'Шпион найден!'
                : 'Шпион победил!',
          ),
          const SizedBox(height: 24),
          Text(
            result['winner'] == 'civilians'
                ? 'Алиби не сработало. Команда верно вычислила шпиона.'
                : 'Шпион остался незамеченным. Компания выбрала мирного игрока.',
            style: const TextStyle(color: NightColors.muted),
          ),
          const SizedBox(height: 24),
          NightPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Шпион: ${spy.name}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Divider(height: 28),
                Text('Локация: ${result['location']}'),
                const Divider(height: 28),
                Text('Вы выбрали: ${suspect.name}'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          NightButton(
            onPressed: () {
              _suspectId = null;
              controller.replay();
            },
            label: 'Ещё раз с теми же игроками',
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
    const NightEyebrow('ПОДГОТОВКА / 01'),
    const SizedBox(height: 16),
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
      onChanged: _clearing ? null : (value) => setState(() => _count = value!),
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
                enabled: !_clearing,
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
    NightButton(
      onPressed: _clearing
          ? null
          : () {
              if (!_formKey.currentState!.validate()) return;
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _settings = true);
            },
      label: 'К настройкам',
    ),
    if (widget.setupStore != null)
      TextButton(
        onPressed: _clearing ? null : _clearSetup,
        child: Text(
          _clearing ? 'Удаляем настройки…' : 'Очистить сохранённые данные',
        ),
      ),
    TextButton(onPressed: _exit, child: const Text('Отменить подготовку')),
  ];

  List<Widget> _settingsContent(SpyController controller) => [
    const NightEyebrow('ПОДГОТОВКА / 02'),
    const SizedBox(height: 16),
    _heading(context, 'Настройки партии'),
    const SizedBox(height: 12),
    const Text(
      'Один раунд. Один шпион. Все свои?',
      style: TextStyle(color: NightColors.muted),
    ),
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
      onChanged: _saving ? null : (value) => setState(() => _minutes = value!),
    ),
    const SizedBox(height: 24),
    Text('Игроков: $_count · один шпион'),
    if (widget.setupStore != null) ...[
      const SizedBox(height: 12),
      const Text(
        'При старте сохраним имена и время. После закрытия приложения начните новый раунд.',
        style: TextStyle(color: NightColors.muted),
      ),
    ],
    const SizedBox(height: 24),
    NightButton(
      onPressed: _saving ? null : () => _start(controller),
      label: _saving ? 'Готовим партию…' : 'Раздать роли',
    ),
    TextButton(
      onPressed: _saving ? null : () => setState(() => _settings = false),
      child: const Text('Изменить имена'),
    ),
    TextButton(onPressed: _exit, child: const Text('Отменить подготовку')),
  ];
}
