# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: application code.
  - `lib/main.dart`: entrypoint; boots `Transportia`.
  - `lib/app.dart`: app shell, routing, locale setup.
  - `lib/screens/`: UI screens (e.g., `map_screen.dart`, `welcome_screen.dart`).
  - `lib/services/`: platform/data services (e.g., `location_service.dart`).
  - `lib/widgets/`: reusable UI components (e.g., `route_field_box.dart`).
- `assets/`: images and static assets (declared in `pubspec.yaml`).
- `test/`: Dart tests (`*_test.dart`).
- Platform runners: `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`.

## Build, Test, and Development Commands
- Install deps: `flutter pub get`
- Run app (auto‑select device): `flutter run`
  - Web example: `flutter run -d chrome`
- Static analysis: `flutter analyze`
- Format code: `dart format .` (CI-friendly check: `dart format . --set-exit-if-changed`)
- Unit tests: `flutter test`
- Coverage (optional): `flutter test --coverage`
- Release builds: `flutter build apk` | `flutter build ios` | `flutter build web`

## Coding Style & Naming Conventions
- Dart/Flutter style, 2-space indent; prefer `final`/`const` and trailing commas.
- File names: `snake_case.dart`. Screens: `*_screen.dart`; services: `*_service.dart`.
- Types: `UpperCamelCase`; members/functions/vars: `lowerCamelCase`.
- Avoid `print`; use logs or comments when necessary.
- Lints: `flutter_lints` configured via `analysis_options.yaml`. Fix all `flutter analyze` issues before submitting.

## Testing Guidelines
- Place tests in `test/` with `_test.dart` suffix (e.g., `route_field_box_test.dart`).
- Use `flutter_test`. Keep tests deterministic; mock location/permissions when needed.
- Aim to cover core logic in `services/` and widget behaviors with golden or widget tests where practical.

## Commit & Pull Request Guidelines
- Commits: concise, imperative subject (e.g., “Improve welcome transition”).
- Group related changes; keep diffs focused. Reference issues if applicable.
- PRs must include:
  - Clear description and rationale.
  - Screenshots/GIFs for UI changes (Map/Welcome flows).
  - Test plan (commands run, devices/simulators tested).
  - Confirmation that `flutter analyze` passes and code is formatted.

## Security & Configuration Tips
- Do not commit secrets or keys. Manage platform permissions via `permission_handler` and update `AndroidManifest.xml`/`Info.plist` as needed.
- Keep `pubspec.yaml` assets in sync (e.g., `assets/images/welcome-image.png`).
