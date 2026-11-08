import 'package:flutter/material.dart';

import 'spy/spy_game_screen.dart';

class PartyBoxApp extends StatelessWidget {
  const PartyBoxApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Вечеро',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBBA1FF),
        brightness: Brightness.dark,
        surface: const Color(0xFF17171D),
      ),
      scaffoldBackgroundColor: const Color(0xFF101014),
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    ),
    home: const CatalogScreen(),
  );
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              Text('ВЕЧЕРО', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 40),
              Text(
                'Собрались?\nДавайте играть.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Телефон по кругу. Интрига за столом.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 40),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.fingerprint,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                        semanticLabel: 'Игра на дедукцию',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Шпион',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('Все знают место. Один делает вид.'),
                      const SizedBox(height: 24),
                      const Text('4–12 игроков · от 5 минут'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Как играть'),
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const SpyRulesScreen(),
                          ),
                        ),
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

class SpyRulesScreen extends StatelessWidget {
  const SpyRulesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Шпион')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Один из вас не в курсе.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            const Text(
              'Передавайте телефон по кругу и смотрите свою карточку. '
              'Все увидят одну локацию, а шпион — только свою роль.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Задавайте друг другу вопросы о месте. Найдите шпиона, '
              'не называя локацию прямо.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Когда время закончится, обсудите подозрения и выберите одного '
              'игрока. Угадали шпиона — победила команда. Ошиблись — победил шпион.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const SpyGameScreen()),
              ),
              child: const Text('Собрать компанию'),
            ),
          ],
        ),
      ),
    ),
  );
}
