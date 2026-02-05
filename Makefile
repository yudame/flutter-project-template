.PHONY: help setup clean build test test-coverage test-watch test-file analyze format gen watch run l10n l10n-check l10n-sort

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Initial project setup (deps, codegen, l10n)
	./scripts/setup.sh

clean: ## Clean build artifacts
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/

build-android: ## Build Android APK
	flutter build apk --release

build-ios: ## Build iOS app
	flutter build ios --release --no-codesign

build-web: ## Build web app
	flutter build web --release

test: ## Run all tests
	./scripts/test/run-all.sh

test-coverage: ## Run tests with coverage report
	./scripts/test/coverage.sh

test-watch: ## Run tests in watch mode (requires entr)
	./scripts/test/watch.sh

test-file: ## Run specific test file (FILE=path/to/test.dart)
	flutter test $(FILE)

analyze: ## Run static analysis
	flutter analyze

format: ## Format code
	dart format lib/ test/

gen: ## Run code generation (freezed, json_serializable, hive)
	flutter pub run build_runner build --delete-conflicting-outputs

watch: ## Run code generation in watch mode
	flutter pub run build_runner watch --delete-conflicting-outputs

run: ## Run the app in debug mode
	flutter run

run-release: ## Run the app in release mode
	flutter run --release

devices: ## List available devices
	flutter devices

doctor: ## Check Flutter installation
	flutter doctor -v

upgrade: ## Upgrade Flutter dependencies
	flutter pub upgrade

outdated: ## Check for outdated packages
	flutter pub outdated

# === Localization ===

l10n: ## Generate localization files
	flutter gen-l10n

l10n-check: ## Check for missing translations
	./scripts/l10n/check-missing.sh

l10n-sort: ## Sort ARB files alphabetically
	./scripts/l10n/sort-arb.sh
