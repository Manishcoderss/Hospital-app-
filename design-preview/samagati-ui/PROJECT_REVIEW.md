# Project review and design mapping

Reviewed the hospital project's lib structure and main patient/staff entry points, patient mock data, dashboard and clinical directory screens. This is a UI review, not a complete backend/security audit.

- lib/main.dart: staff application entry and remembered sessions.
- lib/patient/patient_login.dart: patient OTP/password/create-account demo.
- Patient home and mock data: appointments, records, bills, profile and booking.
- Doctor home/dashboard: queue, today's statistics, follow-ups and patient navigation.
- Clinical modules: patient directory/registration, prescription drafts, lab orders/reports, pharmacy stock and IPD.
- Account screens: profile, sessions and security.

Design: warm cream canvas, forest-green navigation, white cards, muted sage/peach/lavender accents, readable typography and mobile bottom navigation. Patient flows prioritize the next appointment; staff flows prioritize the queue and clinical shortcuts.

The preview deliberately uses fictional fixtures. Existing Firebase/authentication, live hospital services, medical workflows and production permissions must be integrated separately after design approval. No Dart, Android, configuration or signing files were changed.
