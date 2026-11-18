# Current UI choice — original restored

The user requested the original Flutter UI on 17 November 2026. Original patient login/home, clinical screens, colours and entry routing have been restored from the pre-blue backup. The patient standalone entry is again the original demo; it is not the live PatientPortal. API services/contracts and All hospital services remain in the project. Live API completion is still pending the separate test account.

The notes below describe the preceding blue integration and are retained as implementation history, not a claim about the currently active patient UI.

# Blue hospital app — integration review

The approved blue theme is implemented in Flutter. Existing login artwork/layout is retained. Patient accounts route to their own portal, doctor/hospital-admin accounts to the clinical dashboard, and other roles to the service workspace. Doctor navigation includes IPD and All hospital services.

The supplied Postman collection contains 375 request entries, 359 distinct method/path pairs, across 44 groups. Each has a generated request contract and collection-backed form. Existing specialist appointment, prescription, laboratory, pharmacy and account screens remain available. Additional administration/IPD/reporting operations use reusable record, filter, nested-field, file-upload and document-result screens. This coverage is not a claim that every workflow has been verified against the server.

Full inventory: API_COVERAGE.csv. Postman scripts and sample credentials are neither executed nor embedded.

## Configuration

The current hospital host remains the default. Override it with:

    flutter run --dart-define=HOSPITAL_API_URL=https://your-test-hospital/api/v1

Postman's localhost:5000 is a development placeholder. No login account from the collection was used, per the user's instruction.

## Required before release

- Test accounts and a confirmed test-server URL are pending. No authenticated live checks or medical/financial writes were performed.
- Mock HTTP tests verify routing and error handling, not backend field requirements, response envelopes or permissions. The collection contains zero response examples.
- Patient identity must be linked by auth/me as patient_id or patient.id. The app refuses access if this link is absent; it never substitutes a user ID or searches other patients.
- Patient email/password uses real auth. Patient OTP login remains unavailable until the login-OTP exchange is confirmed. Provided OTP examples describe forgot_password rather than patient sign-in.
- Public self-registration is not defined. Hospital reception must create/link the account; production never creates a fake account.
- Login 2FA challenge handling, hospital-switch session transitions, report step-up tokens, FCM delivery and custom-role permissions require real response verification. Request forms exist; full orchestration is not certified.
- File-picker/share menus require Android device checks. Clinical, financial, discharge, stock and consent workflows require review in a test hospital. Recording a payment is not a payment gateway integration.
- Example-derived forms are not a validated OpenAPI schema; required fields and allowed enum values need server confirmation.

Do not treat this as a production-ready release until the pending checks above are resolved.
