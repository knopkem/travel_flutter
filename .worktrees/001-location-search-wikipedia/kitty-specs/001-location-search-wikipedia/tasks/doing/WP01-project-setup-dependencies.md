---
work_package_id: "WP01"
subtasks:
  - "T001"
  - "T002"
  - "T003"
  - "T004"
title: "Project Setup & Dependencies"
phase: "Phase 0 - Foundation"
lane: "doing"
assignee: "Claude"
agent: "claude"
shell_pid: "78763"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-12T00:00:00Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
  - timestamp: "2025-12-12T17:15:00Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "78763"
    action: "Started implementation of project setup and dependencies"
  - timestamp: "2025-12-12T17:20:00Z"
    lane: "doing"
    agent: "claude"
    shell_pid: "78763"
    action: "Completed all subtasks (T001-T004): pubspec.yaml, analysis_options.yaml, directory structure, main.dart. Manual verification pending (Flutter SDK not installed on system)."
---
*Path: kitty-specs/001-location-search-wikipedia/tasks/doing/WP01-project-setup-dependencies.md*

# Work Package Prompt: WP01 – Project Setup & Dependencies

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Initialize Flutter project with all dependencies, linting configuration, and directory structure.

**Success Criteria**:
- `flutter pub get` runs without errors
- `flutter analyze` shows zero warnings
- Project directory structure matches plan.md specification
- main.dart contains basic MaterialApp scaffold

## Context & Constraints

**Prerequisites**: None (this is the starting work package)

**References**:
- [plan.md](../../plan.md) - See "Technical Context" and "Project Structure" sections
- [Constitution](../../../../../.kittify/memory/constitution.md) - Principle I (Modern Dependencies), Principle V (Code Quality)

**Constraints**:
- Use latest stable versions of Flutter 3.x and Dart 3.x
- Dependencies must be actively maintained packages
- Follow Flutter project conventions

## Subtasks & Detailed Guidance

### Subtask T001 – Create pubspec.yaml with dependencies

**Purpose**: Define project metadata and declare all required dependencies.

**Steps**:
1. Create `pubspec.yaml` in project root (if not exists)
2. Set name: `travel_flutter_app`
3. Set description: "A Flutter travel app for searching locations and viewing Wikipedia content"
4. Add dependencies:
   - `provider: ^6.1.0` (or latest stable)
   - `http: ^1.1.0` (or latest stable)
5. Add dev_dependencies:
   - `flutter_lints: ^3.0.0` (or latest)
6. Ensure flutter SDK constraint matches project requirements

**Files**: `pubspec.yaml`

**Parallel?**: No - must be first

**Example pubspec.yaml**:
```yaml
name: travel_flutter_app
description: A Flutter travel app for searching locations and viewing Wikipedia content
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.0
  http: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

---

### Subtask T002 – Configure analysis_options.yaml

**Purpose**: Enable flutter_lints for code quality enforcement.

**Steps**:
1. Create `analysis_options.yaml` in project root
2. Include flutter_lints package
3. Optionally customize specific rules if needed

**Files**: `analysis_options.yaml`

**Parallel?**: Yes (can proceed after T001)

**Example analysis_options.yaml**:
```yaml
include: package:flutter_lints/flutter.yaml

# Customize linter rules if needed
# linter:
#   rules:
#     - prefer_const_constructors
```

---

### Subtask T003 – Create project directory structure

**Purpose**: Establish folder organization per plan.md specification.

**Steps**:
1. Create `lib/models/` directory
2. Create `lib/repositories/` directory
3. Create `lib/providers/` directory
4. Create `lib/widgets/` directory
5. Create `lib/screens/` directory

**Files**: Directory structure under `lib/`

**Parallel?**: Yes (can proceed after T001)

**Command**:
```bash
mkdir -p lib/{models,repositories,providers,widgets,screens}
```

---

### Subtask T004 – Create main.dart scaffold

**Purpose**: Set up basic MaterialApp entry point.

**Steps**:
1. Create `lib/main.dart`
2. Add main() function that runs runApp()
3. Create MyApp widget extending StatelessWidget
4. Return MaterialApp with title and placeholder home
5. Add basic theme configuration (Material Design)

**Files**: `lib/main.dart`

**Parallel?**: No (requires T003 to be complete)

**Example main.dart**:
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Flutter App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Location Search'),
        ),
        body: const Center(
          child: Text('Setup complete - Ready for implementation'),
        ),
      ),
    );
  }
}
```

## Test Strategy

No tests required per constitution (testing on-demand only).

**Manual Verification**:
1. Run `flutter pub get` - should complete without errors
2. Run `flutter analyze` - should show zero warnings
3. Run `flutter run` - app should launch with placeholder screen

## Risks & Mitigations

**Risk**: Version conflicts between Flutter SDK and packages
- **Mitigation**: Use compatible version constraints, test with latest stable Flutter

**Risk**: Linter too strict causing warnings on valid code
- **Mitigation**: Review analysis_options.yaml, suppress specific rules if justified

## Definition of Done Checklist

- [ ] pubspec.yaml created with all dependencies
- [ ] analysis_options.yaml configured with flutter_lints
- [ ] Directory structure created (models, repositories, providers, widgets, screens)
- [ ] main.dart contains working MaterialApp scaffold
- [ ] `flutter pub get` runs successfully
- [ ] `flutter analyze` shows zero warnings
- [ ] `flutter run` launches app successfully
- [ ] tasks.md updated to mark WP01 complete

## Review Guidance

**Verify**:
- Dependencies use latest stable versions
- No deprecated packages
- Directory structure matches plan.md
- Linter configuration appropriate
- Code formatted with `dart format`

## Activity Log

- 2025-12-12T00:00:00Z – system – lane=planned – Prompt created.
