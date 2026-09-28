import os
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SIMULATOR_HTML = os.path.join(BASE_DIR, "cash_simulator.html")

class DummyCashManager:
    def get_status(self):
        return {
            "current_session": None,
            "inventory": {
                "coins_in_tubes": {10: 50, 5: 50, 2: 50, 1: 100},
                "total_change_available": 950,
                "cash_box_total": 0
            }
        }

cash_manager = DummyCashManager()

class MiddlewareRequestHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, data):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path in ["/", "/simulator", "/simulator.html"]:
            if os.path.exists(SIMULATOR_HTML):
                with open(SIMULATOR_HTML, "r", encoding="utf-8") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(content.encode("utf-8"))
            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"cash_simulator.html not found.")
        elif parsed.path == "/api/middleware/cash/status":
            self._send_json(200, cash_manager.get_status())
        else:
            self._send_json(404, {"error": "Not Found"})

if __name__ == "__main__":
    PORT = 8080
    server_address = ("", PORT)
    httpd = HTTPServer(server_address, MiddlewareRequestHandler)
    print(f"Starting Cash Middleware on http://localhost:{PORT}")
    httpd.serve_forever()