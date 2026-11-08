.PHONY: bootstrap check check-mobile backend mobile preview-mobile gallery-mobile

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

preview-mobile:
	cd apps/mobile && flutter build web --release --no-web-resources-cdn --pwa-strategy=none
	python3 -m http.server 8716 --bind 127.0.0.1 --directory apps/mobile/build/web

gallery-mobile:
	cd apps/mobile && flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8717 --dart-define=DESIGN_GALLERY=true
