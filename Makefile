.PHONY: bootstrap check check-mobile backend mobile

bootstrap:
	npm ci
	cd packages/game_core && dart pub get
	cd apps/mobile && flutter pub get

check:
	npm run check
	$(MAKE) check-mobile

check-mobile:
	dart format --output=none --set-exit-if-changed packages/game_core packages/game-content/lib apps/mobile/lib apps/mobile/test apps/mobile/integration_test apps/mobile/tool
	cd packages/game_core && dart analyze --fatal-infos && dart test
	cd apps/mobile && flutter analyze --fatal-infos && flutter test

backend:
	npm run dev:backend

mobile:
	cd apps/mobile && flutter run
