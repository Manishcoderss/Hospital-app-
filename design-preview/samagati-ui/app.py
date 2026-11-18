"""Samagati UI preview. Fictional records, no production integrations.
Run: python app.py --port 8096
Python standard library only. All demo changes reset when the server restarts.
"""
import argparse
import json
import threading
from datetime import date, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
LOCK = threading.Lock()
DOCTORS = [
    {"id": "lakshmi", "name": "Dr. Lakshmi Iyer", "specialty": "General Medicine", "initials": "LI", "color": "green", "experience": "12 years of experience", "fee": 600},
    {"id": "rohan", "name": "Dr. Rohan Shah", "specialty": "Cardiology", "initials": "RS", "color": "peach", "experience": "15 years of experience", "fee": 900},
    {"id": "neha", "name": "Dr. Neha Patel", "specialty": "Dermatology", "initials": "NP", "color": "lavender", "experience": "9 years of experience", "fee": 700},
]

def seed_visits():
    return [
        {"id": "APT-1001", "doctor": "lakshmi", "date": (date.today() + timedelta(days=2)).isoformat(), "time": "10:00 AM", "reason": "General consultation", "status": "Upcoming", "patient": "Aarav Sharma"},
        {"id": "APT-1000", "doctor": "rohan", "date": (date.today() - timedelta(days=7)).isoformat(), "time": "11:30 AM", "reason": "Routine follow-up", "status": "Completed", "patient": "Aarav Sharma"},
    ]

VISITS = seed_visits()

class Handler(BaseHTTPRequestHandler):
    def respond(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/api/demo":
            with LOCK:
                self.respond({"doctors": DOCTORS, "visits": list(VISITS), "today": date.today().isoformat(), "demo": True})
            return
        name = {"/": "index.html", "/index.html": "index.html", "/style.css": "style.css", "/app.js": "app.js"}.get(path)
        if not name:
            self.send_error(404)
            return
        body = (ROOT / name).read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", {"html": "text/html; charset=utf-8", "css": "text/css; charset=utf-8", "js": "text/javascript; charset=utf-8"}[name.rsplit(".", 1)[1]])
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        path = urlsplit(self.path).path
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > 8192:
                return self.respond({"error": "Request too large."}, 413)
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict):
                raise ValueError()
        except (ValueError, TypeError):
            return self.respond({"error": "Please send a valid form."}, 400)
        if path == "/api/appointments":
            try:
                day = date.fromisoformat(data.get("date", ""))
                if day < date.today() or data.get("doctor") not in {d["id"] for d in DOCTORS}:
                    raise ValueError()
                if data.get("time") not in ["09:00 AM", "10:00 AM", "10:30 AM", "11:30 AM", "02:00 PM", "04:00 PM"]:
                    raise ValueError()
                reason = str(data.get("reason", "")).strip()
                if not reason or len(reason) > 250:
                    raise ValueError()
            except (ValueError, TypeError):
                return self.respond({"error": "Choose a doctor, a valid date, a time and a visit reason."}, 400)
            with LOCK:
                if any(v["doctor"] == data["doctor"] and v["date"] == data["date"] and v["time"] == data["time"] and v["status"] == "Upcoming" for v in VISITS):
                    return self.respond({"error": "That demo slot is already booked. Choose another time."}, 409)
                visit = {"id": f"APT-{1000 + len(VISITS)}", "doctor": data["doctor"], "date": day.isoformat(), "time": data["time"], "reason": reason, "status": "Upcoming", "patient": "Aarav Sharma"}
                VISITS.insert(0, visit)
                self.respond(visit, 201)
            return
        if path == "/api/cancel":
            with LOCK:
                visit = next((v for v in VISITS if v["id"] == data.get("id")), None)
                if not visit or visit["status"] != "Upcoming":
                    return self.respond({"error": "This appointment cannot be cancelled."}, 400)
                visit["status"] = "Cancelled"
                self.respond(visit)
            return
        self.respond({"error": "Unknown demo action."}, 404)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8096)
    args = parser.parse_args()
    print(f"Samagati design preview: http://127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
