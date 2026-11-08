# Среда разработки

## Инструменты

- Node 24.15.0 (`.nvmrc`) и npm 11. Используйте `nvm use` или `fnm use`.
- Flutter 3.38.5 (`.fvmrc`), комплектный Dart 3.10.4. Это закреплённая совместимая
  версия, не утверждение о самом свежем релизе. Обновлять отдельно с проверками.
- Git и make; Android Studio/Android SDK и JDK для Android; macOS/Xcode для iOS.

Если Flutter установлен через FVM:

```sh
fvm install
fvm flutter doctor -v
export PATH="$PWD/.fvm/flutter_sdk/bin:$PATH"
```

FVM устанавливается пользователем выбранным способом; репозиторий не меняет глобальные
настройки IDE и агентов. Альтернатива — SDK нужной версии из
[официального архива Flutter](https://docs.flutter.dev/install/archive) в PATH.
При обновлении версии менять `.fvmrc` и `flutter-version` в CI одновременно.

## Установка и проверки

```sh
make bootstrap
make check
```

`make bootstrap` запускает `npm ci`, `dart pub get` для ядра и `flutter pub get`
для приложения. В CI Dart/Flutter используют `--enforce-lockfile`. Все три lockfile
коммитятся. `npm run check` — только Node-часть; `make check-mobile` — Dart/Flutter.
Тест сервера открывает случайный loopback-порт, Dart test также может открывать
локальный сервис. В изолированной среде этим командам нужно разрешить localhost.

```sh
npm run format
dart format packages/game_core packages/game-content/lib apps/mobile/lib apps/mobile/test apps/mobile/integration_test
```

Prettier не форматирует generated native-файлы и Dart. Для Dart используется
комплектный formatter; конфликта двух форматтеров нет.

## Запуск

```sh
make backend
curl http://127.0.0.1:3000/health
```

`tsc-watch` пересобирает TypeScript и перезапускает сервер после успешной компиляции.
По умолчанию сервер слушает только localhost:3000; `HOST` и `PORT` можно передать
переменными окружения. Пример — `apps/backend/.env.example`. `.env` автоматически
не загружается. Для проверки с устройства явно задайте доступный интерфейс:

```sh
HOST=0.0.0.0 PORT=3000 npm run dev:backend
```

Мобильный каркас работает независимо от сервера:

```sh
flutter devices
make mobile
```

Доступен полный локальный цикл «Шпиона», включая повтор с прежними именами.
Настройки и активная партия живут в памяти: после закрытия приложения они теряются.
`packages/game-content` одновременно является npm workspace
для валидации и Flutter-пакетом `partybox_game_content` для доставки assets.
Мобильный клиент использует ключ `packages/partybox_game_content/packs/spy-ru-base.json`;
widget-тест проверяет asset manifest и чтение JSON. Не создавайте вторую ручную копию контента.

## Проверка локальной партии

`make check-mobile` запускает анализ, тесты ядра и widget-тесты. Они покрывают полный
цикл, повтор, передачу, двойное нажатие, скрытие роли в фоне, восстановление deadline,
отмену подготовки и экран 320×640 с масштабом текста 2.

Integration-тест использует тот же полный пользовательский сценарий с реальным
встроенным набором. На подключённом Android/iOS-устройстве или эмуляторе:

```sh
cd apps/mobile
flutter devices
flutter test integration_test/local_game_test.dart -d <device-id>
```

Этот запуск выполняется отдельно от `make check-mobile`: нужен платформенный SDK
и устройство. CI пока запускает только ядро/widget-тесты. Для ручной приёмки:
четыре человека проходят цикл без интернета; при открытой роли свернуть приложение,
вернуться и убедиться, что карточка закрыта; во время обсуждения уйти в фон дольше
выбранного времени и проверить переход к выбору подозреваемого. Проверить также
системный «Назад»: во время партии нужен диалог, отмена оставляет роль закрытой.

## Превью выбранного дизайна PB-015

```sh
make preview-mobile
```

Открыть http://localhost:8716. Это настоящий локальный игровой цикл Flutter
в web host; сервер игры не требуется. Сборка использует локальные fonts/CanvasKit
и отключает service worker, чтобы изменения не скрывались кешем старой версии.
Если ранее запускали старое web-превью с service worker, один раз удалить данные
именно этого localhost origin в браузере или открыть приватное окно.
Для галереи компонентов в non-release режиме: `make gallery-mobile`, порт 8717.
Команды требуют Python 3 и Flutter в PATH. Сборка для web не заменяет Android/iOS.
Подробности: [DESIGN_SYSTEM](DESIGN_SYSTEM.md), [снимки и проверки](design/pb-015/verification.md).

## Нативные проекты

Android/iOS host-проекты сгенерированы Flutter 3.38.5. Временный namespace/bundle ID
начинается с `dev.partybox.prototype`; перед store-сборками заменить осознанно и
проверить deep links, подпись и developer accounts. Отображаемое название —
Вечеро (временное название); иконки пока шаблонные. Release-подпись ещё не настроена.

Изменения native-файлов проверяются настоящей сборкой нужной платформы, а не только
`flutter analyze`. Сборка Android: `flutter build apk --debug` из `apps/mobile` при
наличии SDK/JDK. iOS: `flutter build ios --no-codesign` на macOS с Xcode.

## Git и совместная работа

Основная ветка `main`; рабочие ветки `feat/pb-010-local-session`, `fix/...`, `docs/...`.
Содержательное изменение → подходящие проверки → PR с кратким сценарием и результатом.
Инструкции одинаковы для человека и агента: [AGENTS.md](../AGENTS.md).
Для длительной работы — [шаблон плана](plans/TEMPLATE.md); передача результата через
`docs/STATUS.md`, а не через скрытую память конкретного агента.

Remote `origin`: `https://github.com/danilagarev/vechero.git`.
После публикации включить обязательные CI-проверки `node` и `flutter` для `main`.
CI не отправляет приложение в магазины. Подпись и deployment требуют отдельной настройки.

## Источники решений

- [Архитектура Flutter](https://docs.flutter.dev/app-architecture/guide).
- [Начало работы с NestJS](https://docs.nestjs.com/first-steps).
- [Инструкции Codex через AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
- [Гарантии доставки Socket.IO](https://socket.io/docs/v4/delivery-guarantees/).
