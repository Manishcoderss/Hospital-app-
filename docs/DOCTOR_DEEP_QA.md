# Doctor integration audit - 17 November 2026

Scope: preserve the original UI, audit doctor functionality, fix reproduced defects and run authenticated live read checks. The user confirmed that the supplied patient and appointment identifiers are dummy records for testing. This does not bypass backend identity, permissions or record-state validation.

## Reproduced defects and fixes

1. Sign-out cleared the remembered session but never called `/auth/logout`. It now calls the documented current-session revocation API, prevents duplicate submissions and still signs out locally if the server is offline. A failed remote revocation is clearly reported rather than claimed successful. No clinical write is retried.
2. Profile's Undo/Save action row overflowed by 5.6 pixels at phone width in a new regression test. Actions now wrap when necessary; the original styling is retained.
3. Doctor profile roles are trimmed and normalized consistently before role-specific routing.

## Local checks

- Focused audit/logout/profile tests: `doctor-deep-focused.log`.
- Full regression suite: `doctor-deep-tests.log`.
- Analyzer: `doctor-deep-analysis.log`.
- Android debug build: `doctor-deep-build.log`.
- Regression tests verify remote logout status handling, offline fallback, duplicate protection, original profile layout, doctor-only read scope, stop-on-expiry/rate-limit and redaction of logs.

## Live audit method

`DoctorReadAudit` is opt-in through the debug-only `DOCTOR_LIVE_QA` define. Ordinary builds and release builds do not start it. It uses the session already authenticated inside the Android app; no password/token is extracted or written into a report. Its HTTP wrapper rejects all non-GET requests and stops new requests after 401/429.

Existing service methods and parsers are exercised for profile, dashboard, today's queue, appointments, own doctor ID, doctor dropdown/available slots, patients/lookups, prescriptions, laboratory stages/catalog/categories, stock, sessions/security, notification settings and notifications. Schedule/recent-patient endpoints are checked at envelope level; this does not certify every individual field. Dummy record detail endpoints are checked with identity validation; patient visit/lab reads require a valid dummy patient response first.

Reports contain fixed check labels, classifications and HTTP status codes only. No screenshots, response payloads, patient names, identifiers, token values or passwords are captured. A 403 is recorded as restricted rather than falsely claimed as an integrated successful workflow. A 404 may mean a wrong identifier, missing record or missing route and needs investigation. HTTP 200 with a parser failure is reported as a contract error.

## Remaining limits

Live results are pending installation/login of the audit build. The earlier user-confirmed live login/dashboard/appointments/profile smoke check remains valid but is not a substitute for this endpoint audit.

Clinical mutation checks remain pending successful dummy-record identity validation and suitable fixtures. No live prescription, appointment status, lab order, payment or stock record has been written by this audit. Two-factor login and hospital-selection flows still need confirmed server response contracts. Read checks cannot certify every medical workflow, hardware print/share behavior or production readiness.

## Live endpoint result

Authenticated Android audit: **22 service/parser checks passed**, no permission denials. The report is `doctor-live-read-report.log`. This covers current-user/doctor identity, dashboard, queue, appointments, own doctor profile, booking doctors/slots, schedule/recent-patient envelopes, patients/lookups, prescriptions, labs/stages/catalog/categories, stock, sessions/security and notifications/preferences.

The two dummy detail checks returned 404. The user then confirmed that the supplied values were display record numbers, not backend IDs. This is an input identifier mismatch; it is not evidence that the existing detail API routes are absent. No clinical write was attempted with these values.

The next debug build provides an explicit read-check button on an opened patient/appointment detail screen. After the tester confirms it is a dummy record, the app uses that selected record's real ID in process and runs only the relevant read checks. No identifier is exported. Normal/release builds do not show this control. Record checks validate patient/appointment linkage rather than trusting display numbers.

A separate opt-in logout probe calls auth/me with the old access token after successful logout and reports only its HTTP status. A 401 verifies access-token invalidation; this does not separately prove refresh-token revocation.

Verification after these additions: 32 targeted tests passed (`doctor-record-tests.log`), following the earlier 159-test full suite. Static analysis has zero errors/warnings and five existing informational suggestions. Clinical write verification remains pending validated selected dummy records and suitable test inputs.
## Final local validation and installed artifact

- Final full suite: **163 tests passed**, no failures (`doctor-final-tests.log`).
- Analyzer: zero errors/warnings, five pre-existing informational suggestions (`doctor-deep-analysis.log`).
- Final Android debug build succeeded (`doctor-selected-record-build.log`) and was installed with `adb install -r` on the connected Samsung phone. Data was not wiped.
- APK SHA256: `B0886A977871DDB4656A338FC4F02A295B4600000405F3BA7DFB606CB33F3F60`.
- Original patient login/home remain byte-identical to the original backup. Patient live OTP integration is deferred.
- The installed test build has QA enabled but no guessed patient/appointment IDs. The selected-record checks and sign-out invalidation probe require the user's phone actions. At the final check, this app process had emitted no new QA status lines yet; these live steps remain pending.
- No live clinical writes, screenshots, credential extraction or medical-payload exports were performed.
## Additional phone-driven live checks

The connected phone was operated through whitelisted accessibility controls. Only fixed labels, booleans and tap bounds were output; screenshots and patient/credential values were not captured.

- Current app process completed the full 22-check read audit with **22 passed, 0 restricted, 0 failed** (`doctor-live-final-report.log`).
- Actual Profile sign-out was confirmed: `/auth/logout` returned **200**, then the same old access token received **401** from auth/me. Login navigation was visible afterwards. The app correctly invalidated access; refresh-token revocation is still not separately probed.
- With Remember me disabled, restart returned to Login, as expected. After enabling it and the user privately logging in, force-stop/relaunch restored authenticated doctor navigation and the fresh process completed all 22 read checks (`doctor-live-restore-report.log`). No token was extracted.
- An authorized patient detail screen rendered its expected fixed labels. Scoped Visit History and Lab Reports displayed their loaded states without Retry/error controls. These were read-only checks, not dummy clinical-write tests. Neither identifiers nor counts/findings were exported.
- Patient number search and the subsequently supplied name did not produce the requested dummy record. The user then confirmed that no dummy patient is registered.
- A new **unsaved** registration form was prepared: first name QA, last name Doctor Test, age 30. No Register/Save submission has been sent. Required test mobile, ID-proof, address and emergency-contact information must be supplied privately on the phone by the user. Live record creation and write testing remain pending that data and the user's explicit save/test confirmation.
## Authorized synthetic registration follow-up

The user authorized filling all dummy details on the testing doctor account. A clearly marked QA Doctor Test draft was entered on the connected Samsung phone. Registration received a definite backend rejection; no successful patient creation has been confirmed. Do not retry an unknown-outcome request or use existing real patients for write tests.

Found a usability gap: registration discarded validation metadata and showed only a generic rejection. The service now reports the HTTP rejection code and allowlisted field labels from structured validation metadata. Echoed inputs and arbitrary server messages remain hidden. A focused regression verifies that private messages and inputs cannot appear in the error.

The opt-in DOCTOR_LIVE_QA debug build includes an explicitly invoked Fill unsaved QA dummy details control. It fills a draft with synthetic QA identifiers only and never sends a request. It is absent in release builds and ordinary debug builds. Saving remains a separate action.

### Confirmed live QA patient creation

After checking the directory for duplicates (QA search returned No patients match), the fresh QA draft was submitted through the visible upper part of the button. The new QA Doctor Test patient detail opened successfully. Selected-record GET checks passed: identity, doctor scope, patient detail, visits, and labs; audit summary pass=4, restricted=0, failed=0. Redacted proof: doctor-live-qa-patient-report.log. No further patient registration is needed.

Observed the bottom submit button extending into the Android navigation area. Registration list padding now includes MediaQuery.viewPadding.bottom so its last control can scroll above the system inset.

During live prescription selection, found a contract mismatch: patient dropdown used module=prescriptions while the supplied Postman collection specifies module=prescription. Corrected the request and the existing test that repeated the same mistake; added a focused contract regression. Live prescription save/issue and appointment writes are not yet proven.

Automatic approval initially rejected a repeated submit while its outcome was unclear. Work continued using a read-only directory search; only after confirming no QA patient matched was a fresh submission approved. No approval bypass or unknown-outcome blind retry was used.

### Live appointment and prescription draft write tests passed

On the same synthetic QA patient, appointment dropdown search returned the exact QA record. Booked one appointment using the doctor's available future slot with the reason QA TEST ONLY - workflow verification. The resulting appointment detail and its patient linkage passed the selected-record audit (summary pass=5, restricted=0, failed=0). Redacted proof: doctor-live-qa-appointment-report.log.

Verified the workflow through scheduled -> confirmed (Check in) -> consultation started (Complete consultation action appeared) -> completed. The completed state was visible on the same QA patient with no update error. Boolean-only proof: doctor-live-write-report.log. No diagnosis, treatment or follow-up was entered.

From that appointment, Write prescription opened with the correct QA patient preselected. Saved one empty prescription draft containing only an explicit QA TEST ONLY - no clinical treatment marker. The saved detail showed draft status and the QA patient. Pressing Issue correctly displayed Add at least one medicine or lab test before issuing and kept the draft state. No successful Issue POST, lab order, stock change, dispense or billing write has been performed.

The standalone prescription dropdown returned HTTP 200 with an items list containing zero records during the pre-appointment search. This is a verified response, not proof of a client crash or a confirmed backend cause. Appointment-to-prescription drafting works. Do not claim the standalone lookup or successful Issue workflow is fully verified until retested.

The user will provide the exact existing dummy medicine/lab test name for the remaining successful Issue test. Do not substitute a real medicine or order a real lab test.

Validation after the API module/inset changes: full suite 165 passed; focused registration/prescription tests 8 passed. Analysis: zero errors/warnings and five pre-existing informational lints. Updated QA APK installed over the existing app with saved session retained. Only opt-in debug lookup diagnostics were added afterward; they report HTTP status and result count, never names/IDs/queries/tokens/payloads.

## Successful live Issue test (user-supplied test medicine)

The user supplied Amlong 5 / Amlodipine and explicitly confirmed quantity 1 for QA software testing. On the previously verified QA patient and completed appointment, saved a separate draft with Amlong 5 quantity 1, no dose/frequency, an explicit QA ISSUE TEST ONLY - NOT FOR TREATMENT marker and QA TEST ONLY - DO NOT DISPENSE OR USE instructions. Review confirmed the QA patient and one medicine, zero lab tests. Confirm Issue was submitted once.

Issue succeeded. A fresh server reload still displayed the QA patient, issued status, expected medicine and quantity one. Boolean-only proof is in doctor-live-issue-report.log. No dispense, stock, lab-order or billing write was performed. This is software workflow verification, not a clinical prescription recommendation. The earlier empty QA draft remains a draft; the medication QA draft is issued.

Retested the corrected standalone prescription patient lookup after the appointment/prescription existed. Backend returned HTTP 200, items list with one result, and the exact QA Doctor Test option appeared. Redacted status/count proof: doctor-live-lookup-after-issue-report.log. The previous pre-appointment result was zero; this does not establish the backend's exact filter rule. No additional standalone draft was saved: its local test form was discarded afterward. Do not claim selected-history loading passed independently; that final selection was not confirmed.

No source changes were required in this Issue follow-up. The prior 165 passing automated tests and focused 8 passing tests remain applicable; they were not redundantly rerun. Live proof supplements those mocked tests. Broad guarantees about every role, all collection APIs, real printing, dispensing, billing, and patient OTP login are outside these completed doctor workflow checks.

## Doctor-only follow-up: expired standalone search session

Patient login work is explicitly deferred at the user's request. During the remaining doctor standalone prescription selection/history check, the existing remembered session returned HTTP 401 on patient dropdown GETs. No patient history selection was claimed as successful on that expired session.

Fixed NewPrescriptionPage.searchPatients to preserve the service's sanitized Session expired / permission error instead of replacing it with a generic search failure. Search now clears prior results before a new request so an expired or failed lookup cannot leave stale selectable results. No raw backend messages are exposed.

Added a widget regression exercising a successful search followed by HTTP 401, verifying the sign-in message, removal of prior QA results, no exposed backend message, and GET-only traffic. Both focused new_prescription_page tests passed. Analyzer reports zero errors/warnings with the same five pre-existing infos. Build log: doctor-selection-build.log. The expired session was signed out through the normal app flow. Fresh private login is needed for the final live history check; no credentials were accessed.

## Remaining doctor standalone history check completed

Fresh doctor login was entered privately by the user. The fresh session's read-only audit passed all 22 checks (doctor-live-fresh-session-report.log). The updated QA APK was built successfully and installed without clearing app storage. Its remembered doctor session restored after installation.

On the UPDATED build, standalone prescription lookup returned HTTP 200 and one QA result. Selected the unique exact QA Doctor Test option. Patient detail was fetched, selected/returned ID verified, supported history parsed and copied to the editor, search results/search text cleared, and loading finished. The opt-in pass-only DOCTOR_SELECTION_QA|patient_history|pass diagnostic confirmed the completion point. No patient field values, IDs or credentials were logged. Redacted proof: doctor-live-selection-report.log. The local unsaved form was discarded afterward; no further patient, appointment, prescription or issue write was performed in this follow-up.

The earlier explicit pending standalone history check is now CLOSED for this QA patient/session. The expired-search error handling fix is installed: sanitized session/permission messages are retained and stale search results cleared. Added identity-mismatch regression verifies the service's existing rejection blocks copying another patient's data. Three focused editor tests pass (doctor-selection-tests.log). Changed-file analysis reports No issues found (doctor-selection-focused-analysis.log); project-wide analysis earlier had only the same five pre-existing infos. Historical full suite: 165 passed; do not mislabel the newly added focused tests as a fresh full-suite run.

Doctor scope completed here: login/logout, session restore, 22 API reads, QA registration and patient records, appointment booking/status completion, prescription draft save, empty-Issue guard, successful quantity-one Issue with server reload, standalone dropdown and selected history loading. Broader role coverage, patient OTP login, real printer/device matrix, dispensing/stock/billing and actual lab processing remain outside this doctor workflow verification. Patient login work remains explicitly deferred. No zero-bug guarantee is implied.
