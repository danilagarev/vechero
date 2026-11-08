import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design/night_art.dart';
import 'design/night_components.dart';
import 'design/night_gallery.dart';
import 'design/night_theme.dart';
import 'spy/spy_game_screen.dart';
import 'storage/spy_setup.dart';

class PartyBoxApp extends StatelessWidget {
  const PartyBoxApp({super.key, this.setupStore});
  final SpySetupStore? setupStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Вечеро',
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: nightTheme(),
    home: const bool.fromEnvironment('DESIGN_GALLERY') && !kReleaseMode
        ? const NightGallery()
        : CatalogScreen(setupStore: setupStore),
  );
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, this.setupStore});
  final SpySetupStore? setupStore;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              const Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 24,
                runSpacing: 8,
                children: [
                  NightEyebrow('ВЕЧЕРО', color: NightColors.text),
                  NightEyebrow('ОДИН ТЕЛЕФОН'),
                ],
              ),
              const SizedBox(height: 36),
              NightEntrance(
                child: Text.rich(
                  TextSpan(
                    text: 'Хороший вечер.\n',
                    children: const [
                      TextSpan(
                        text: 'Плохое алиби.',
                        style: TextStyle(color: NightColors.accent),
                      ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Соберите компанию.\nОстальное — за нами.',
                style: TextStyle(color: NightColors.muted),
              ),
              const SizedBox(height: 28),
              NightPanel(
                accent: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NightEyebrow('ДЕДУКЦИЯ / 01', color: NightColors.ink),
                    const NightArt(color: NightColors.accent),
                    Text(
                      'Шпион',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 48,
                        color: NightColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Все знают место.\nОдин делает вид.'),
                    const SizedBox(height: 20),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        NightBadge('4–12 игроков', dark: true),
                        NightBadge('от 5 минут', dark: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    NightButton(
                      dark: true,
                      label: 'Как играть',
                      onPressed: () => Navigator.of(context).push<void>(
                        NightRoute(
                          builder: (_) =>
                              SpyRulesScreen(setupStore: setupStore),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Телефон по кругу. Интрига за столом.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: NightColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SpyRulesScreen extends StatelessWidget {
  const SpyRulesScreen({super.key, this.setupStore});
  final SpySetupStore? setupStore;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ШПИОН')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const NightEyebrow('ПРАВИЛА / ОДИН РАУНД'),
              const SizedBox(height: 16),
              Text(
                'Один из вас не в курсе.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              const NightRule(
                number: '01',
                title: 'Телефон по кругу',
                text:
                    'Все знают место, кроме шпиона. Посмотрите роль, скройте и передайте телефон.',
              ),
              const SizedBox(height: 12),
              const NightRule(
                number: '02',
                title: 'У кого плохое алиби?',
                text:
                    'Спрашивайте о месте. Найдите шпиона, не называя локацию.',
              ),
              const SizedBox(height: 12),
              const NightRule(
                number: '03',
                title: 'Решайте вместе',
                text:
                    'Проголосуйте вслух. Нашли шпиона — выиграли. Ошиблись — победил он.',
              ),
              const SizedBox(height: 24),
              NightButton(
                label: 'Собрать компанию',
                onPressed: () => Navigator.of(context).push<void>(
                  NightRoute(
                    builder: (_) => SpyGameScreen(setupStore: setupStore),
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
