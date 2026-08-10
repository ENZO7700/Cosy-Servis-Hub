# Testing Guide

## Test Structure

```
test/
├── unit/           # Pure logic (CRM, Isar, AutoOps engine, …)
├── widget/         # UI (CRM, lead inbox, AI assistant, …)
├── repository/     # Lead repository native / web
├── integration/    # Workflows, integrity, lead inbox, offline queue, …
└── smoke/          # Offline diagnostic smokes (e.g. lead import)
```

Ops smoke script (Flutter + CORS/edge): `./tool/smoke_lead_diagnostic.sh`  
Aktuálny audit: [`docs/PROJECT_DIAGNOSTICS.md`](docs/PROJECT_DIAGNOSTICS.md)

## Test Categories

### Unit Tests (`test/unit/`)
- Test pure Dart logic
- Test model serialization/deserialization
- Test business logic
- **No** Flutter widgets, **no** Isar runtime, **no** network calls
- Run: `flutter test test/unit`

### Widget Tests (`test/widget/`)
- Test individual widgets
- Test widget rendering and interactions
- Use `pumpWidget`, `tap`, `enterText`, etc.
- **No** real Isar runtime (use mocks where possible)
- Run: `flutter test test/widget`

### Repository Tests (`test/repository/`)
- Test data access layer
- Test Isar persistence (native) or IndexedDB (web)
- Requires Isar initialization
- Run: `flutter test test/repository`

### Integration Tests (`test/integration/`)
- Test complete user workflows
- Test authentication flows
- Requires Firebase emulation, Isar, network access
- **These tests may fail in CI without proper setup**
- Run manually: `flutter test test/integration`

## Playwright integrity / e2e (web)

Node-based Playwright suite lives in `e2e/`:

```
e2e/
├── helpers/env.ts
├── integrity/          # API + deployed web integrity
│   ├── api.integrity.spec.ts
│   └── app.integrity.spec.ts
└── browser/            # light browser smoke
    └── smoke.spec.ts
```

### Install (once)
```bash
npm install
npx playwright install chromium
# optional full browsers + system deps:
npm run playwright:install:all
```

### Run
```bash
# Integrity only (Supabase REST, lead-assistant, Firebase hosting)
npm run test:integrity

# All Playwright projects
npm run test:e2e

# Against another deploy
E2E_BASE_URL=https://flutterdashb-h4ck3d.vercel.app npm run test:integrity

# Optional live AI parse
FIREBASE_ID_TOKEN='...' npm run test:integrity

# HTML report
npm run test:e2e:report
```

Default target: `https://machinegunslots.web.app`  
Secrets are read from `secrets.json` or env (`VITE_SUPABASE_*`, `VITE_FIREBASE_API_KEY`).

### iPhone 17 Air Premium polish (pl-PL)
```bash
npm run test:iphone-air
# report + PNG:
# e2e/artifacts/iphone-17-air-premium-report.md
# e2e/artifacts/iphone-17-air-premium-home.png
```
Prompt: `e2e/prompts/iphone-17-air-premium-polish.prompt.md`

## Running Tests

### All Tests
```bash
flutter test
```


### By Category
```bash
# Unit tests
flutter test test/unit

# Widget tests
flutter test test/widget

# Repository tests
flutter test test/repository

# Smoke (offline diagnostics)
flutter test test/smoke

# Integration tests (run manually)
flutter test test/integration

# Lead-assistant diagnostic smoke
./tool/smoke_lead_diagnostic.sh
```

### With Coverage
```bash
flutter test --coverage test/unit test/widget test/repository
```

## CI/CD

GitHub Actions workflows are configured in `.github/workflows/`:

- **test.yml** - Runs on every push/PR:
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test test/unit`
  - `flutter test test/widget`
  - `flutter test test/repository`
  - `flutter build web --release`

- **integration.yml** - Runs manually (weekly):
  - Integration tests (require additional setup)

## Current Test Status

| Category | Status | Count | Notes |
|----------|--------|-------|-------|
| Unit | ✅ PASS | 3 | crm_test.dart, isar_test.dart |
| Widget | ✅ PASS | 4 | crm_ui_test.dart, lead_inbox_ui_test.dart, widget_test.dart |
| Repository | ✅ PASS | 2 | lead_repository_native_test.dart, lead_repository_web_test.dart |
| Integration | ⚠️ SKIP | 2 | Requires Firebase/Isar setup |

**Total Passing: 9 tests**

## Best Practices

1. **Use stable identifiers** - Don't test against specific text from simulated responses. Use widget keys or state.
2. **Mock external services** - Don't make real HTTP calls in tests.
3. **Keep tests isolated** - Each test should set up its own state and clean up.
4. **Use `pumpAndSettle()`** - Wait for animations and async operations.
5. **Prefer `find.byKey()`** - More stable than `find.byText()`.

## Writing Good Tests

### Unit Test Example
```dart
test('CrmLead serialization', () {
  final lead = CrmLead(
    id: 'test-123',
    companyName: 'Test Company',
    createdAt: DateTime.now(),
    importedAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  
  final json = lead.toJson();
  final fromJson = CrmLead.fromJson(json);
  
  expect(fromJson.id, equals(lead.id));
  expect(fromJson.companyName, equals(lead.companyName));
});
```

### Widget Test Example
```dart
testWidgets('LeadCard displays correctly', (WidgetTester tester) async {
  final lead = createTestLead();
  
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LeadCard(lead: lead),
      ),
    ),
  );
  
  expect(find.text(lead.companyName), findsOneWidget);
  expect(find.text(lead.contactName), findsOneWidget);
});
```

## Troubleshooting

### Isar Initialization Errors
If tests fail with `Isar initialization failed`, ensure:
1. Isar is properly initialized in `setUpAll()`
2. Test is running on supported platform (native or web)
3. Isar version matches across test and production

### Network Call Errors
Integration tests may fail if:
1. Firebase is not properly mocked
2. Network requests time out
3. Required secrets are missing

**Solution**: Use mock services or run with `--tags integration` only when Firebase emulation is available.

## Test Data

Use the `createTestLead()` helper (to be created) for consistent test data:

```dart
import '../helpers/test_helpers.dart';

final lead = createTestLead(
  companyName: 'Test Company',
  email: 'test@example.com',
);
```
