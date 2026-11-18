# Validation — 17 November 2026

- Full staged regression run: 140 tests passed (including two local visual-render checks).
- After final visit/navigation/sign-out fixes: 27 affected checks passed; six patient/record-routing checks passed, including three newly added cases.
- All 375 generated operation contracts dispatched through mocked HTTP with encoded route parameters. This verifies client routing only, not live backend acceptance.
- Applied project analyzer: zero errors and warnings; four informational style notes.
- Actual Flutter patient and doctor screenshots inspected: docs/screenshots.
- Applied project Android debug APK compiled successfully using lib/main.dart.
- APK: build/app/outputs/flutter-apk/app-debug.apk
- SHA256: 66303345389BCDE51EC59120A6A19ADA47698BB4B6A201F1579123E2CA7CFCA2
- Public /api/health returned HTTP 200. Public response-schema URLs checked returned 404.
- No Postman sample login accounts used. No authenticated live integration, real medical/financial changes, device installation or physical-device checks performed.

Release blockers and workflow gaps: API_INTEGRATION.md. Test credentials and confirmed test-server responses are required to complete end-to-end verification. This APK is a debug review build, not a production release.
