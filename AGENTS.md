# CampX Attendance Manager (Calcdence) - Agent Guidelines

Welcome, AI Coding Assistant! This `AGENTS.md` file contains the essential context, rules, and commands needed to operate effectively within the CampX Attendance Manager codebase. Please read and adhere to these guidelines for all code generation, refactoring, and bug-fixing tasks.

## 1. Project Context & Stack
- **Framework:** Flutter (Dart 3.10.3+)
- **State Management:** `provider` pattern.
- **Networking:** `http` package for direct API calls to CampX.
- **Storage:** `flutter_secure_storage` (session/credentials) & `shared_preferences` (settings/theme).
- **Core Features:** Attendance tracking, "Bunk Calculator", Timetable viewing.

---

## 2. Essential Commands

### Build & Run
- **Run the App:**
  ```bash
  flutter run
  ```
- **Clean the Build (if encountering caching issues):**
  ```bash
  flutter clean && flutter pub get
  ```

### Linting & Formatting
- **Analyze Code (Linting):**
  ```bash
  flutter analyze
  ```
  *Always ensure zero analysis errors before committing changes. We use `flutter_lints: ^6.0.0`.*
- **Format Code:**
  ```bash
  dart format lib test
  ```
  *Run this on all changed files to maintain a consistent style.*

### Testing
- **Run All Tests:**
  ```bash
  flutter test
  ```
- **Run a Single Test File:**
  ```bash
  flutter test test/path_to_test_file.dart
  ```
- **Run a Specific Test within a File (by name):**
  ```bash
  flutter test --plain-name "name of the specific test" test/path_to_test_file.dart
  ```
- **Run Tests with Coverage:**
  ```bash
  flutter test --coverage
  ```
- **Update Golden Tests (if applicable):**
  ```bash
  flutter test --update-goldens
  ```

---

## 3. Code Style & Conventions

### 3.1. General Dart & Flutter Practices
- **Null Safety:** Strict null safety is enforced. Use `?`, `!`, `late`, and `??` correctly. Avoid `!` unless absolutely certain a value is non-null.
- **Immutability:** Use `const` constructors for widgets wherever possible to optimize the widget tree rebuilds. Mark variables as `final` if they are not reassigned.
- **Async/Await:** Prefer `async/await` over `.then()` chains for readability.
- **Types:** Always provide explicit return types for functions/methods. Use `final` and `const` for immutability.
- **Widget Refactoring:** If a file grows beyond ~300 lines or contains complex UI parts, extract reusable pieces into `lib/widgets/`.

### 3.2. Naming Conventions
- **Classes, Enums, Typedefs:** `PascalCase` (e.g., `AttendanceProvider`, `SubjectModel`).
- **Files & Directories:** `snake_case` (e.g., `attendance_provider.dart`, `home_screen.dart`).
- **Variables & Methods:** `camelCase` (e.g., `fetchAttendance()`, `bunkableClasses`).
- **Constants:** `lowerCamelCase` (e.g., `defaultApiTimeout`) or scoped within a class (e.g., `class ApiConstants { static const String baseUrl = ... }`).
- **Private Members:** Prefix with an underscore `_` (e.g., `_isLoading`).

### 3.3. Imports
- Use **relative imports** for files within the `lib/` directory (e.g., `import '../models/subject.dart';`).
- Use **package imports** for external dependencies and core Flutter packages (e.g., `import 'package:flutter/material.dart';`).
- Group imports: Dart/Flutter core first, followed by external packages, then relative imports.

---

## 4. Architecture & Organization

The `lib/` directory is structured by feature layer:
- **`models/`**: Pure Dart data classes. Must include `fromJson`/`toJson` factories if interacting with the API. Keep them free of business logic (except simple computed getters).
- **`providers/`**: Business logic and state management extending `ChangeNotifier`. These classes orchestrate API calls, update internal state, and call `notifyListeners()`.
- **`screens/`**: UI components. Use `Consumer<T>` or `context.watch<T>()` to rebuild parts of the UI. Avoid putting heavy business logic here.
- **`services/`**: External communications (e.g., `CampXApiService`, storage services, notification services). These should be stateless or manage their own isolated state.
- **`constants.dart`**: Shared constant values. *Note: Avoid hardcoding dynamic data (like subjects) here if possible; rely on the API.*

### State Management (`provider`) Rules
- Separate UI from logic. UI widgets should only dispatch actions to providers.
- Use `Consumer` widgets to rebuild only the specific parts of the UI that depend on the changing state, rather than rebuilding the entire screen.
- Avoid passing providers down the widget tree manually; use `Provider.of` or `context.read()`/`context.watch()`.

---

## 5. Error Handling
- **API Errors:** The `CampXApiService` should catch network or parsing exceptions and either return a standardized error object or throw a descriptive custom exception.
- **Provider Layer:** Providers must catch exceptions thrown by services. They should set an error state (e.g., `_errorMessage = e.toString()`) and call `notifyListeners()` so the UI can display a `SnackBar` or error widget.
- **UI Feedback:** Never let the app silently fail. Always provide clear feedback (Loading spinners, SnackBars for errors, or generic "Something went wrong" messages).
- **Avoid Empty Catches:** Never use an empty `catch (e) {}` block. At a minimum, log the error or use `debugPrint`.

---

## 6. Testing Guidelines
- **Unit Tests:** Focus on testing business logic, especially mathematical calculations like the "Bunk Calculator" (`AttendanceCalculator`). Ensure edge cases (0 classes, exactly at threshold, etc.) are covered.
- **Widget Tests:** Test core UI flows and ensure UI states (Loading, Error, Success) render correctly. Mock providers and services using packages like `mockito` or `mocktail`.
- **Mocking:** Do not make real HTTP requests in tests. Inject a mock `http.Client` or mock the `CampXApiService` entirely.

---

## 7. Security & Privacy
- **Do not commit secrets:** Never commit API keys, plaintext passwords, or sensitive institutional configurations.
- **Secure Storage:** Always use `flutter_secure_storage` for sensitive data like the `campx_session_key`. Do not use `shared_preferences` for secure tokens.

## 8. UX & UI Guidelines
- **No Emojis:** Do not use emojis in user-facing text, notifications, or UI components. It gives the impression of a cheap AI-generated product. Maintain a clean, professional, and native appearance.

## 9. Development Workflow for Agents
1. **Analyze:** Read the relevant files (`models`, `providers`, `screens`) to understand the local context.
2. **Plan:** Ensure you aren't violating the separation of concerns (e.g., adding API logic to a Screen).
3. **Execute:** Write the code, ensuring `const` usage and strict typing.
4. **Verify:** Run `dart format` and `flutter analyze` before concluding your task. Run relevant tests using `flutter test`.
