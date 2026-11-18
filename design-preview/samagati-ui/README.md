# Samagati hospital UI preview

Separate HTML/CSS/JavaScript interface with a Python standard-library demo server. Original Flutter files are unchanged.

Run with Python 3: `python app.py --port 8096`, then open http://127.0.0.1:8096.

Patient dashboard: /#patient/home
Doctor dashboard: /#doctor/home
Login preview: /#login

All patients, doctors, health information and payments are fictional. OTP is 123456. Password login accepts any demo password of four or more characters. This is not real authentication. Booking/cancellation use an in-memory Python API and reset when the server restarts. Profile edits remain in this browser only. Clinical drafts and bill payments are UI demonstrations; no hospital API or payment service is connected.

Features: responsive patient/doctor dashboards, appointment booking and cancellation, doctor directory, records and sample text downloads, bills, profile editing, queue search/filter, patients, prescriptions, laboratory, pharmacy and IPD previews.
