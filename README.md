# PartyBox

Игры для компании от четырёх человек на Android и iOS. Два режима: один телефон
передаётся по кругу и каждый играет со своего телефона. Стиль — премиальный;
целевой результат — публикация в магазинах.

Сейчас это фундамент разработки: Flutter-каркас, чистое Dart-ядро первой игры,
проверяемый JSON-контент, NestJS health endpoint и CI. Полная игровая UX-цепочка,
сетевая игра и покупки — следующие этапы, а не готовые возможности.

## Быстрый старт

Нужны Node из `.nvmrc`, npm 11 и Flutter из `.fvmrc` (с комплектным Dart).

```sh
make bootstrap
make check
make mobile
```

Для работы только с сервером и контентом Flutter не нужен:

```sh
npm ci
npm run check
npm run dev:backend
```

Проверка сервера: `curl http://127.0.0.1:3000/health` → `{"status":"ok"}`.
Инструкции по платформенным SDK, FVM и портам: [разработка](docs/DEVELOPMENT.md).

## Карта проекта

| Путь                      | Назначение                                      |
| ------------------------- | ----------------------------------------------- |
| `apps/mobile`             | Flutter-клиент Android/iOS                      |
| `packages/game_core`      | Правила локальной игры, чистый Dart             |
| `apps/backend`            | NestJS; будущий авторитетный сервер             |
| `packages/game-contracts` | Версионированные JSON-схемы                     |
| `packages/game-content`   | Авторский контент и его валидация               |
| `docs`                    | Требования, архитектура, правила, backlog и ADR |

Начало работы агента: [AGENTS.md](AGENTS.md). Следующая задача:
[backlog](docs/BACKLOG.md). Фактическое состояние: [STATUS](docs/STATUS.md).
Причины выбора стека: [архитектура](docs/ARCHITECTURE.md).

GitHub Actions запускает Node- и Flutter-проверки после push/PR. Для защиты `main`
нужно после подключения remote включить обязательные проверки `node` и `flutter`
в настройках хостинга. Remote, публикация и production-секреты не настроены.
