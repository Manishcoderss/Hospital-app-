# Doctor-first verification — 17 November 2026

The current scope is the original doctor/staff UI and doctor login. Patient login/backend work is deferred. The existing patient demo has not been changed. Mobile-number/OTP patient authentication needs a confirmed backend login contract; the collection's forgot-password OTP requests do not establish that contract.

## Changes

- A known patient account can no longer enter the staff dashboard from password login or saved sign-in. A rejected saved patient session is cleared locally.
- Original dashboard tabs have stable widget keys. This does not change their appearance.
- Restored-UI tests now use the original custom queue tabs and verify the authenticated doctor's session rather than expecting a name label absent from the original design.
- Regression coverage includes email trimming without changing the password, inactive/reset-required accounts, malformed/server/network errors, small-phone keyboard layout, disabled submit while signing in, patient/staff separation, refresh-token restoration and secure persistence.

## Verification

The 25 focused authentication/dashboard/session tests passed in `doctor-focused-tests.log`.
Final full suite: **146 passed**, no failures (`doctor-test-result.log`). Static analysis: no errors or warnings; five existing informational suggestions (`doctor-analysis.log`). Android debug APK built successfully (`doctor-debug-build.log`).

Existing workflow tests cover doctor-scoped dashboards and visits, appointment booking/statuses, patient records, prescription drafts/review/issue/allergy conflicts, labs, pharmacy, profile and sign-out confirmation. These use fictional data and mocked HTTP responses. They are not proof of live backend compatibility or production readiness.

## Live checks still required

- The user supplied a separate test email; no Postman sample account has been used. The password must be entered by the user on the Android login screen.
- Verify login, actual role/hospital identity, scoped dashboard/visits, restart with Remember me, incorrect password, session expiry and sign out against the test backend.
- Mutating clinical workflows require explicit test-hospital fixtures and confirmation that they are safe test records. No live medical/financial writes have been performed.
- 2FA challenges and hospital-selection transitions require confirmed server responses; these flows are not certified complete.
- Superseded by DOCTOR_DEEP_QA.md: server-side logout is now integrated and regression-tested. Live old-token invalidation still needs the phone sign-out check.

The connected Android device is used only for the user's requested app test. Installation must preserve app data; do not uninstall or clear storage to resolve a signature mismatch.

## Android smoke check

- Samsung Galaxy A14 5G (SM-A146B), Android 15, 1080 × 2408.
- Updated debug APK installed with `adb install -r`; no uninstall or storage wipe.
- MainActivity launched successfully and the app process remained running.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- SHA256: `D137DAB0DE344E259ABF56AE32AA871ACAFF4A6DC9445CF9AEF05CA3A40684A5`.
- The user entered the test account credentials on the phone and confirmed that login opened the dashboard. The user also confirmed that Visits/Appointments loads correctly and Profile shows the correct doctor name/role. Live session-expiry/restart/sign-out and clinical write workflows remain unverified.

No dashboard screenshot was captured. Automatic review rejected persistent screenshot capture because patient/medical information could be present. Further live UI checks use the user’s observations without capturing medical records.
