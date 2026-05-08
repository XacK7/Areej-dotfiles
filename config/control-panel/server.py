"""Control panel HTTP server.

Serves static files from web/ and dispatches /api/<panel-id>/<subpath> to the
matching handler module in handlers/. Panels are auto-discovered at startup —
adding a new panel is dropping a .py in handlers/ and a .js in web/panels/.
"""
import importlib.util
import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

from handlers._safe import HandlerError

DEFAULT_ROOT = Path(__file__).parent
DEFAULT_WEB = DEFAULT_ROOT / "web"
DEFAULT_HANDLERS = DEFAULT_ROOT / "handlers"


def _load_handlers(handlers_dir: Path):
    handlers = {}
    for f in sorted(handlers_dir.glob("*.py")):
        if f.stem.startswith("_") or f.stem == "__init__":
            continue
        spec = importlib.util.spec_from_file_location(
            f"_cp_handler_{f.stem}", f)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        if not hasattr(mod, "handle"):
            raise RuntimeError(f"handler {f} missing handle() function")
        handlers[f.stem] = mod
    return handlers


def _generate_panels_index(web_dir: Path):
    """Write web/panels/index.js re-exporting every <name>.js as a default."""
    panels_dir = web_dir / "panels"
    if not panels_dir.exists():
        return
    panels = sorted(p.stem for p in panels_dir.glob("*.js")
                    if p.stem != "index")
    lines = []
    for name in panels:
        lines.append(f'import {name} from "./{name}.js";')
    lines.append("")
    lines.append("export default [" + ", ".join(panels) + "];")
    (panels_dir / "index.js").write_text("\n".join(lines) + "\n")


def build_server(host="127.0.0.1", port=0, web_dir=None, handlers_dir=None):
    web_dir = Path(web_dir) if web_dir else DEFAULT_WEB
    handlers_dir = Path(handlers_dir) if handlers_dir else DEFAULT_HANDLERS

    parent = str(handlers_dir.parent)
    if parent not in sys.path:
        sys.path.insert(0, parent)

    handlers = _load_handlers(handlers_dir)
    _generate_panels_index(web_dir)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            pass

        def _send_json(self, status, payload):
            data = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _serve_static(self, rel):
            target = (web_dir / rel.lstrip("/")).resolve()
            try:
                target.relative_to(web_dir.resolve())
            except ValueError:
                self.send_error(400)
                return
            if target.is_dir():
                target = target / "index.html"
            if not target.is_file():
                self.send_error(404)
                return
            ext = target.suffix.lower()
            ctype = {
                ".html": "text/html",
                ".css": "text/css",
                ".js": "application/javascript",
                ".json": "application/json",
                ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
                ".png": "image/png", ".svg": "image/svg+xml",
                ".ico": "image/x-icon",
            }.get(ext, "application/octet-stream")
            data = target.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _dispatch_api(self, method):
            path = self.path.split("?", 1)[0]
            assert path.startswith("/api/")
            rest = path[len("/api/"):]
            if rest == "_panels":
                self._send_json(200, [
                    {"id": pid} for pid in sorted(handlers.keys())
                ])
                return
            if "/" in rest:
                panel_id, subpath = rest.split("/", 1)
            else:
                panel_id, subpath = rest, ""
            mod = handlers.get(panel_id)
            if not mod:
                self.send_error(404, f"unknown panel: {panel_id}")
                return
            body = None
            if method == "POST":
                length = int(self.headers.get("Content-Length", "0"))
                raw = self.rfile.read(length) if length else b""
                if raw:
                    try:
                        body = json.loads(raw)
                    except json.JSONDecodeError:
                        self.send_error(400, "invalid JSON body")
                        return
            try:
                status, payload = mod.handle(method, subpath, body)
            except HandlerError as e:
                self._send_json(e.status, {"error": e.message})
                return
            except Exception as e:
                self._send_json(500, {"error": str(e)})
                return
            self._send_json(status, payload)

        def do_GET(self):
            if self.path.startswith("/api/"):
                self._dispatch_api("GET")
            else:
                self._serve_static(self.path or "/")

        def do_POST(self):
            if self.path.startswith("/api/"):
                self._dispatch_api("POST")
            else:
                self.send_error(405)

    httpd = HTTPServer((host, port), Handler)
    return httpd


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=0)
    args = ap.parse_args()
    httpd = build_server(host=args.host, port=args.port)
    print(f"control-panel listening on http://{args.host}:{httpd.server_address[1]}",
          flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
