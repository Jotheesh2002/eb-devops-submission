import os
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

APP_NAME = os.getenv("APP_NAME", "unknown")
VERSION = os.getenv("VERSION", "unknown")
HOSTNAME = socket.gethostname()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            response = {
                "app": APP_NAME,
                "version": VERSION,
                "pod": HOSTNAME
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())
        elif self.path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"ok")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress default logging
        pass

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8080), Handler)
    print(f"Server running on :8080")
    server.serve_forever()
