# Control Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a modular browser-based control panel for Sway that ships notes, wallpaper, and color theme panels in v1, with a per-panel module contract so future settings drop in without core changes.

**Architecture:** Python stdlib `http.server` bound to loopback, opened in `chromium --app=`. Per-panel `handlers/<id>.py` (auto-discovered) on the backend; per-panel `web/panels/<id>.js` ES modules on the frontend. Color theme uses templatized config files for rofi/waybar/mako/foot; pink-green preset is byte-equivalent to current configs.

**Tech Stack:** Python 3 stdlib only at runtime (no pip install); pytest for backend tests; vanilla HTML/CSS/ES-modules on the frontend (no toolchain).

**Spec:** `docs/superpowers/specs/2026-05-08-control-panel-design.md`.

**Repo conventions:**
- All paths in this plan are forward-slash, repo-relative or `~`-relative.
- Auto-commit after each task per `memory/feedback_auto_commit.md`.
- Existing notes directory is `~/.local/share/waybar-notes/`, not `~/.local/share/notes/` — spec uses the latter; this plan uses the former (the live path).

---

## Task 1: Scaffold + `safe_join` helper

Lay out the directory tree, add a dev-dependency file, and ship the one piece of shared backend code (`safe_join`) with tests so every later task can use it.

**Files:**
- Create: `config/control-panel/__init__.py`
- Create: `config/control-panel/handlers/__init__.py`
- Create: `config/control-panel/handlers/_safe.py`
- Create: `config/control-panel/web/panels/.gitkeep`
- Create: `config/control-panel/themes/.gitkeep`
- Create: `config/control-panel/templates/.gitkeep`
- Create: `config/control-panel/tests/__init__.py`
- Create: `config/control-panel/tests/conftest.py`
- Create: `config/control-panel/tests/test_safe.py`
- Create: `config/control-panel/requirements-dev.txt`

- [ ] **Step 1: Create the directory tree**

```bash
mkdir -p config/control-panel/handlers
mkdir -p config/control-panel/web/panels
mkdir -p config/control-panel/themes
mkdir -p config/control-panel/templates
mkdir -p config/control-panel/tests
touch config/control-panel/__init__.py
touch config/control-panel/handlers/__init__.py
touch config/control-panel/tests/__init__.py
touch config/control-panel/web/panels/.gitkeep
touch config/control-panel/themes/.gitkeep
touch config/control-panel/templates/.gitkeep
```

- [ ] **Step 2: Write `requirements-dev.txt`**

```
pytest>=7.0
```

- [ ] **Step 3: Write `tests/conftest.py`**

```python
"""Shared pytest config: makes the package importable via sys.path."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
```

- [ ] **Step 4: Write the failing test for `safe_join`**

`config/control-panel/tests/test_safe.py`:

```python
import pytest
from pathlib import Path
from handlers._safe import safe_join, HandlerError


def test_safe_join_normal(tmp_path):
    base = tmp_path
    (base / "a.txt").write_text("hi")
    assert safe_join(base, "a.txt") == base / "a.txt"


def test_safe_join_subdir(tmp_path):
    sub = tmp_path / "sub"
    sub.mkdir()
    (sub / "b.txt").write_text("hi")
    assert safe_join(tmp_path, "sub/b.txt") == sub / "b.txt"


def test_safe_join_rejects_dotdot(tmp_path):
    with pytest.raises(HandlerError):
        safe_join(tmp_path, "../escape")


def test_safe_join_rejects_absolute(tmp_path):
    with pytest.raises(HandlerError):
        safe_join(tmp_path, "/etc/passwd")


def test_safe_join_rejects_symlink_escape(tmp_path):
    outside = tmp_path.parent / "outside.txt"
    outside.write_text("nope")
    link = tmp_path / "link"
    try:
        link.symlink_to(outside)
    except (OSError, NotImplementedError):
        pytest.skip("symlinks not supported on this platform")
    with pytest.raises(HandlerError):
        safe_join(tmp_path, "link")
```

- [ ] **Step 5: Run test to verify it fails**

```bash
cd config/control-panel
python -m pytest tests/test_safe.py -v
```
Expected: ImportError / ModuleNotFoundError on `handlers._safe`.

- [ ] **Step 6: Implement `safe_join` and `HandlerError`**

`config/control-panel/handlers/_safe.py`:

```python
"""Path-safety helper shared by every handler.

Every panel handler that takes user-supplied path fragments MUST funnel them
through `safe_join`. The function rejects anything that, after resolving
symlinks and normalising, would land outside `base`.
"""
from pathlib import Path


class HandlerError(Exception):
    """Raised by handlers (and helpers) to produce a clean 4xx response."""
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


def safe_join(base, fragment: str) -> Path:
    base = Path(base).resolve()
    if not fragment or fragment.startswith("/") or "\\" in fragment:
        raise HandlerError(400, f"invalid path: {fragment!r}")
    target = (base / fragment).resolve()
    try:
        target.relative_to(base)
    except ValueError:
        raise HandlerError(400, f"path escapes base: {fragment!r}")
    return target
```

- [ ] **Step 7: Run tests to verify they pass**

```bash
cd config/control-panel
python -m pytest tests/test_safe.py -v
```
Expected: 5 passed (or 4 passed + 1 skipped if symlinks unsupported).

- [ ] **Step 8: Commit**

```bash
git add config/control-panel
git commit -m "Scaffold control-panel directory and safe_join helper

Lays out the per-panel handler/web/themes/templates/tests structure and
ships the path-safety helper every handler will use to validate
user-supplied path fragments."
```

---

## Task 2: Server core with handler auto-discovery

The HTTP server: serves `web/`, dispatches `/api/<panel-id>/<subpath>` to the matching handler module, and exposes `/api/_panels` (panel metadata).

**Files:**
- Create: `config/control-panel/server.py`
- Create: `config/control-panel/tests/test_server.py`

- [ ] **Step 1: Write the failing integration test**

`config/control-panel/tests/test_server.py`:

```python
import json
import threading
import urllib.request
from pathlib import Path

import pytest

from server import build_server


@pytest.fixture
def server(tmp_path):
    """Boot a server with a temp web/ and handlers/ dir on an ephemeral port."""
    web = tmp_path / "web"
    web.mkdir()
    (web / "index.html").write_text("<html>hi</html>")
    (web / "panels").mkdir()

    handlers_dir = tmp_path / "handlers"
    handlers_dir.mkdir()
    (handlers_dir / "__init__.py").write_text("")
    (handlers_dir / "ping.py").write_text(
        "def handle(method, subpath, body):\n"
        "    return 200, {'pong': subpath, 'method': method}\n"
    )

    httpd = build_server(host="127.0.0.1", port=0, web_dir=web,
                         handlers_dir=handlers_dir)
    port = httpd.server_address[1]
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()
    yield f"http://127.0.0.1:{port}"
    httpd.shutdown()
    httpd.server_close()


def _get(url):
    with urllib.request.urlopen(url) as resp:
        return resp.status, json.loads(resp.read())


def test_serves_index(server):
    with urllib.request.urlopen(server + "/") as resp:
        assert resp.status == 200
        assert b"hi" in resp.read()


def test_panels_endpoint_lists_handler(server):
    status, body = _get(server + "/api/_panels")
    assert status == 200
    assert any(p["id"] == "ping" for p in body)


def test_dispatches_to_handler(server):
    status, body = _get(server + "/api/ping/foo/bar")
    assert status == 200
    assert body == {"pong": "foo/bar", "method": "GET"}


def test_unknown_panel_returns_404(server):
    with pytest.raises(urllib.error.HTTPError) as exc:
        _get(server + "/api/nope/x")
    assert exc.value.code == 404
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd config/control-panel
python -m pytest tests/test_server.py -v
```
Expected: ModuleNotFoundError on `server`.

- [ ] **Step 3: Implement `server.py`**

`config/control-panel/server.py`:

```python
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

    # Make sure the test-supplied handlers_dir is on sys.path so its
    # _safe.py-importing modules can find handlers._safe.
    parent = str(handlers_dir.parent)
    if parent not in sys.path:
        sys.path.insert(0, parent)

    handlers = _load_handlers(handlers_dir)
    _generate_panels_index(web_dir)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            pass  # quiet by default

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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd config/control-panel
python -m pytest tests/test_server.py -v
```
Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
git add config/control-panel/server.py config/control-panel/tests/test_server.py
git commit -m "Add server core with handler auto-discovery

Static file serving plus /api/<panel>/<subpath> dispatch to handlers
discovered from handlers/. Panels list available at /api/_panels;
web/panels/index.js is regenerated on startup so dropping a new panel
file is enough — no manual registration."
```

---

## Task 3: Notes handler

Backend for the notes panel. Reads from and writes to `~/.local/share/waybar-notes/` (the directory the existing waybar rotation script already uses).

**Files:**
- Create: `config/control-panel/handlers/notes.py`
- Create: `config/control-panel/tests/test_notes.py`

- [ ] **Step 1: Write the failing tests**

`config/control-panel/tests/test_notes.py`:

```python
import os
from pathlib import Path

import pytest


@pytest.fixture
def notes(tmp_path, monkeypatch):
    monkeypatch.setenv("CONTROL_PANEL_NOTES_DIR", str(tmp_path))
    # reload the module after env var is set
    import importlib
    import handlers.notes as m
    importlib.reload(m)
    return m


def test_list_empty(notes):
    status, body = notes.handle("GET", "list", None)
    assert status == 200
    assert body == []


def test_save_then_list(notes, tmp_path):
    status, body = notes.handle("POST", "save",
                                {"title": "shopping", "body": "milk\neggs"})
    assert status == 200
    note_id = body["id"]
    status, listing = notes.handle("GET", "list", None)
    assert status == 200
    assert len(listing) == 1
    assert listing[0]["id"] == note_id
    assert listing[0]["title"] == "shopping"


def test_get_after_save(notes):
    _, saved = notes.handle("POST", "save",
                            {"title": "t", "body": "hello"})
    status, got = notes.handle("GET", f"get/{saved['id']}", None)
    assert status == 200
    assert got["title"] == "t"
    assert got["body"] == "hello"


def test_save_with_id_overwrites(notes):
    _, first = notes.handle("POST", "save",
                            {"title": "v1", "body": "x"})
    _, second = notes.handle("POST", "save",
                             {"id": first["id"], "title": "v2", "body": "y"})
    assert second["id"] == first["id"]
    _, got = notes.handle("GET", f"get/{first['id']}", None)
    assert got["title"] == "v2"
    assert got["body"] == "y"


def test_delete(notes):
    _, saved = notes.handle("POST", "save",
                            {"title": "doomed", "body": ""})
    status, body = notes.handle("POST", f"delete/{saved['id']}", None)
    assert status == 200
    assert body == {"ok": True}
    _, listing = notes.handle("GET", "list", None)
    assert listing == []


def test_get_missing_returns_404(notes):
    from handlers._safe import HandlerError
    with pytest.raises(HandlerError) as exc:
        notes.handle("GET", "get/does-not-exist", None)
    assert exc.value.status == 404


def test_id_path_traversal_rejected(notes):
    from handlers._safe import HandlerError
    with pytest.raises(HandlerError):
        notes.handle("GET", "get/../../etc/passwd", None)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd config/control-panel
python -m pytest tests/test_notes.py -v
```
Expected: ModuleNotFoundError on `handlers.notes`.

- [ ] **Step 3: Implement `handlers/notes.py`**

`config/control-panel/handlers/notes.py`:

```python
"""Notes panel backend.

Storage is one .txt file per note in NOTES_DIR. Filename format is
<isoZ-timestamp>-<slug>.txt; first line of the file is the title, rest is the
body. Compatible with the existing waybar rotating-notes script which reads
the same directory.
"""
import os
import re
import time
from datetime import datetime, timezone
from pathlib import Path

from handlers._safe import safe_join, HandlerError

NOTES_DIR = Path(os.environ.get(
    "CONTROL_PANEL_NOTES_DIR",
    str(Path.home() / ".local/share/waybar-notes")
))


def _ensure_dir():
    NOTES_DIR.mkdir(parents=True, exist_ok=True)


def _slugify(s: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9]+", "-", s.strip()).strip("-").lower()
    return s[:40] or "note"


def _new_id(title: str) -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{stamp}-{_slugify(title)}"


def _read(path: Path):
    text = path.read_text(encoding="utf-8")
    if "\n" in text:
        title, body = text.split("\n", 1)
    else:
        title, body = text, ""
    return title, body


def _list():
    _ensure_dir()
    out = []
    for f in sorted(NOTES_DIR.glob("*.txt"), reverse=True):
        try:
            title, _ = _read(f)
        except OSError:
            continue
        out.append({
            "id": f.stem,
            "title": title or "(untitled)",
            "mtime": f.stat().st_mtime,
        })
    return out


def _resolve(note_id: str) -> Path:
    _ensure_dir()
    path = safe_join(NOTES_DIR, note_id + ".txt")
    return path


def handle(method, subpath, body):
    if method == "GET" and subpath == "list":
        return 200, _list()

    if method == "GET" and subpath.startswith("get/"):
        note_id = subpath[len("get/"):]
        path = _resolve(note_id)
        if not path.is_file():
            raise HandlerError(404, "note not found")
        title, b = _read(path)
        return 200, {
            "id": note_id, "title": title, "body": b,
            "mtime": path.stat().st_mtime,
        }

    if method == "POST" and subpath == "save":
        body = body or {}
        title = (body.get("title") or "").strip()
        text_body = body.get("body") or ""
        note_id = body.get("id") or _new_id(title or "untitled")
        path = _resolve(note_id)
        path.write_text((title + "\n" + text_body), encoding="utf-8")
        return 200, {"id": note_id}

    if method == "POST" and subpath.startswith("delete/"):
        note_id = subpath[len("delete/"):]
        path = _resolve(note_id)
        if path.is_file():
            path.unlink()
        return 200, {"ok": True}

    raise HandlerError(404, f"unknown route: {method} {subpath}")
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd config/control-panel
python -m pytest tests/test_notes.py -v
```
Expected: 7 passed.

- [ ] **Step 5: Commit**

```bash
git add config/control-panel/handlers/notes.py config/control-panel/tests/test_notes.py
git commit -m "Add notes handler

Reads/writes ~/.local/share/waybar-notes (the same dir the existing
waybar rotating-notes script uses) so the new panel and old rofi flow
share storage."
```

---

## Task 4: Wallpaper handler

Lists images in the source directory, tracks current selection, and (when applied) writes a state file plus optionally invokes `swaybg`.

**Files:**
- Create: `config/control-panel/handlers/wallpaper.py`
- Create: `config/control-panel/tests/test_wallpaper.py`

- [ ] **Step 1: Write the failing tests**

`config/control-panel/tests/test_wallpaper.py`:

```python
import json
from pathlib import Path

import pytest


@pytest.fixture
def wp(tmp_path, monkeypatch):
    src = tmp_path / "wallpapers"
    src.mkdir()
    for name in ("a.jpg", "b.png", "ignore.txt"):
        (src / name).write_bytes(b"x")
    state = tmp_path / "state"
    state.mkdir()
    monkeypatch.setenv("CONTROL_PANEL_WALLPAPER_DIR", str(src))
    monkeypatch.setenv("CONTROL_PANEL_STATE_DIR", str(state))
    monkeypatch.setenv("CONTROL_PANEL_SKIP_RELOAD", "1")
    import importlib
    import handlers.wallpaper as m
    importlib.reload(m)
    return m, src, state


def test_list_filters_to_images(wp):
    mod, src, state = wp
    status, body = mod.handle("GET", "list", None)
    assert status == 200
    names = sorted(item["name"] for item in body)
    assert names == ["a.jpg", "b.png"]


def test_set_writes_state(wp):
    mod, src, state = wp
    status, body = mod.handle("POST", "set", {"name": "a.jpg"})
    assert status == 200 and body == {"ok": True}
    assert (state / "wallpaper.current").read_text().strip() == "a.jpg"


def test_set_rejects_unknown_name(wp):
    from handlers._safe import HandlerError
    mod, _, _ = wp
    with pytest.raises(HandlerError) as exc:
        mod.handle("POST", "set", {"name": "ghost.jpg"})
    assert exc.value.status == 404


def test_set_rejects_traversal(wp):
    from handlers._safe import HandlerError
    mod, _, _ = wp
    with pytest.raises(HandlerError):
        mod.handle("POST", "set", {"name": "../evil.jpg"})


def test_current_after_set(wp):
    mod, _, _ = wp
    mod.handle("POST", "set", {"name": "b.png"})
    status, body = mod.handle("GET", "current", None)
    assert status == 200 and body == {"name": "b.png"}


def test_dir_get_and_set(wp, tmp_path):
    mod, src, state = wp
    new_src = tmp_path / "other"
    new_src.mkdir()
    (new_src / "z.jpg").write_bytes(b"x")
    status, body = mod.handle("POST", "dir", {"path": str(new_src)})
    assert status == 200
    status, body = mod.handle("GET", "dir", None)
    assert body["path"] == str(new_src)
    status, listing = mod.handle("GET", "list", None)
    assert [i["name"] for i in listing] == ["z.jpg"]
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd config/control-panel
python -m pytest tests/test_wallpaper.py -v
```
Expected: ModuleNotFoundError on `handlers.wallpaper`.

- [ ] **Step 3: Implement `handlers/wallpaper.py`**

`config/control-panel/handlers/wallpaper.py`:

```python
"""Wallpaper panel backend.

Lists image files from the configured source directory, tracks the current
selection in a small state file, and (unless CONTROL_PANEL_SKIP_RELOAD is set)
asks swaybg to reload after a change.
"""
import os
import shlex
import subprocess
from pathlib import Path

from handlers._safe import safe_join, HandlerError

IMG_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def _state_dir() -> Path:
    p = Path(os.environ.get(
        "CONTROL_PANEL_STATE_DIR",
        str(Path.home() / ".config/control-panel")
    ))
    p.mkdir(parents=True, exist_ok=True)
    return p


def _dir_file() -> Path:
    return _state_dir() / "wallpaper.dir"


def _current_file() -> Path:
    return _state_dir() / "wallpaper.current"


def _src_dir() -> Path:
    env = os.environ.get("CONTROL_PANEL_WALLPAPER_DIR")
    if env:
        return Path(env)
    f = _dir_file()
    if f.is_file():
        return Path(f.read_text().strip())
    return Path.home() / "wallpapers"


def _list():
    src = _src_dir()
    if not src.is_dir():
        return []
    out = []
    for f in sorted(src.iterdir()):
        if f.is_file() and f.suffix.lower() in IMG_EXTS:
            out.append({"name": f.name,
                        "thumb_url": f"/api/wallpaper/thumb/{f.name}"})
    return out


def _reload_swaybg(path: Path):
    if os.environ.get("CONTROL_PANEL_SKIP_RELOAD"):
        return
    # Best-effort: kill any existing swaybg, start a new one.
    subprocess.run(["pkill", "-x", "swaybg"], check=False)
    subprocess.Popen(
        ["swaybg", "-i", str(path), "-m", "fill"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def handle(method, subpath, body):
    if method == "GET" and subpath == "list":
        return 200, _list()

    if method == "GET" and subpath == "current":
        f = _current_file()
        return 200, {"name": f.read_text().strip() if f.is_file() else None}

    if method == "POST" and subpath == "set":
        body = body or {}
        name = body.get("name") or ""
        path = safe_join(_src_dir(), name)
        if not path.is_file():
            raise HandlerError(404, f"wallpaper not found: {name}")
        _current_file().write_text(name)
        _reload_swaybg(path)
        return 200, {"ok": True}

    if method == "GET" and subpath == "dir":
        return 200, {"path": str(_src_dir())}

    if method == "POST" and subpath == "dir":
        body = body or {}
        path = Path(body.get("path") or "").expanduser()
        if not path.is_dir():
            raise HandlerError(400, f"not a directory: {path}")
        _dir_file().write_text(str(path))
        return 200, {"ok": True}

    raise HandlerError(404, f"unknown route: {method} {subpath}")
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd config/control-panel
python -m pytest tests/test_wallpaper.py -v
```
Expected: 6 passed.

- [ ] **Step 5: Commit**

```bash
git add config/control-panel/handlers/wallpaper.py config/control-panel/tests/test_wallpaper.py
git commit -m "Add wallpaper handler

Lists images in the source dir, tracks current selection in
~/.config/control-panel/wallpaper.current, and (when not running under
tests) hands off to swaybg for the actual reload."
```

---

## Task 5: Theme palettes + templates with byte-equivalence test

Define the three preset palettes and the four config templates. Verify that rendering `pink-green` through every template produces a file byte-equivalent to the corresponding live config.

**Files:**
- Create: `config/control-panel/themes/pink-green.json`
- Create: `config/control-panel/themes/blue-cyan.json`
- Create: `config/control-panel/themes/amber-violet.json`
- Create: `config/control-panel/templates/rofi.theme.rasi.tmpl`
- Create: `config/control-panel/templates/waybar.style.css.tmpl`
- Create: `config/control-panel/templates/mako.config.tmpl`
- Create: `config/control-panel/templates/foot.ini.tmpl`
- Create: `config/control-panel/_theme_render.py` (shared renderer used by handler + test)
- Create: `config/control-panel/tests/test_theme_templates.py`

- [ ] **Step 1: Write `themes/pink-green.json`**

```json
{
  "name": "pink-green",
  "label": "Pink & Green",
  "colors": {
    "bg":       "#1e1b2e",
    "bg_alt":   "#2d2b3d",
    "fg":       "#f8f8f2",
    "accent":   "#f48fb1",
    "accent_2": "#e91e8c",
    "ok":       "#a8d8a8",
    "muted":    "#888888"
  }
}
```

- [ ] **Step 2: Write `themes/blue-cyan.json`**

```json
{
  "name": "blue-cyan",
  "label": "Deep Blue & Cyan",
  "colors": {
    "bg":       "#0f1729",
    "bg_alt":   "#1e2a44",
    "fg":       "#e6edf3",
    "accent":   "#7dd3fc",
    "accent_2": "#0ea5e9",
    "ok":       "#86efac",
    "muted":    "#7d8590"
  }
}
```

- [ ] **Step 3: Write `themes/amber-violet.json`**

```json
{
  "name": "amber-violet",
  "label": "Amber & Violet",
  "colors": {
    "bg":       "#1c1033",
    "bg_alt":   "#2a1a4d",
    "fg":       "#f5e6d3",
    "accent":   "#fbbf24",
    "accent_2": "#a78bfa",
    "ok":       "#86efac",
    "muted":    "#9ca3af"
  }
}
```

- [ ] **Step 4: Write the shared renderer `_theme_render.py`**

`config/control-panel/_theme_render.py`:

```python
"""Palette → derived fields → template rendering.

Used by both the theme handler (for live application) and the templatization
safety test (for byte-equivalence verification).
"""
import re
from pathlib import Path


def derive(palette: dict) -> dict:
    """Flatten a palette JSON into a dict of substitutable keys.

    Produces three forms per color slot:
      colors.<slot>      → "#rrggbb"
      colors.<slot>_hex  → "rrggbb"
      colors.<slot>_rgb  → "r, g, b"
    """
    out = {}
    for slot, value in palette["colors"].items():
        v = value.lstrip("#")
        if len(v) != 6:
            raise ValueError(f"bad hex for {slot}: {value!r}")
        r, g, b = int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16)
        out[f"colors.{slot}"] = "#" + v
        out[f"colors.{slot}_hex"] = v
        out[f"colors.{slot}_rgb"] = f"{r}, {g}, {b}"
    return out


_PLACEHOLDER = re.compile(r"\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}")


def render(template_text: str, palette: dict) -> str:
    fields = derive(palette)

    def sub(match):
        key = match.group(1)
        if key not in fields:
            raise KeyError(f"unknown placeholder: {key}")
        return fields[key]

    return _PLACEHOLDER.sub(sub, template_text)


def render_file(template_path: Path, palette: dict) -> str:
    return render(Path(template_path).read_text(encoding="utf-8"), palette)
```

- [ ] **Step 5: Write `templates/rofi.theme.rasi.tmpl`**

This is a copy of the current `config/rofi/theme.rasi` with palette colors replaced by `{{colors.*}}` placeholders.

```
/* Areej's Rofi theme — pink & green */

* {
    bg:         {{colors.bg}};
    bg-alt:     {{colors.bg_alt}};
    fg:         {{colors.fg}};
    pink:       {{colors.accent}};
    hot-pink:   {{colors.accent_2}};
    green:      {{colors.ok}};
    muted:      {{colors.muted}};

    background-color: transparent;
    text-color:       @fg;
}

window {
    width:            440px;
    padding:          14px;
    border:           2px solid;
    border-radius:    14px;
    border-color:     @pink;
    background-color: @bg;
}

mainbox {
    background-color: transparent;
    children:         [ "textbox-banner", listview ];
    spacing:          12px;
}

/* ── Banner (wallpaper) ─────────────────────── */
textbox-banner {
    expand:           false;
    height:           170px;
    background-image: url("/home/areej/wallpapers/wallpaper.jpg", width);
    border-radius:    10px;
    str:              "";
}

/* ── Hidden inputbar (no search) ────────────── */
inputbar {
    enabled: false;
}

/* ── Results list ───────────────────────────── */
listview {
    background-color: transparent;
    spacing:          4px;
    lines:            10;
    columns:          1;
    fixed-height:     false;
    cycle:            true;
}

element {
    padding:          8px 12px;
    border-radius:    8px;
    background-color: transparent;
    orientation:      horizontal;
    spacing:          10px;
}

element selected {
    background-color: @pink;
    text-color:       @bg;
}

element-icon {
    size:             24px;
    vertical-align:   0.5;
}

element-text {
    vertical-align:   0.5;
    text-color:       inherit;
}

element normal active {
    text-color: @green;
}
```

- [ ] **Step 6: Write `templates/waybar.style.css.tmpl`**

Copy of the current `config/waybar/style.css` with palette colors replaced. Inline `rgba(...)` lines use `_rgb` form.

```css
/* Areej's Waybar — pink & green theme */

* {
    border:        none;
    border-radius: 0;
    font-family:   "Noto Sans", "Font Awesome 6 Free", sans-serif;
    font-size:     13px;
    min-height:    0;
}

window#waybar {
    background:    rgba({{colors.bg_rgb}}, 0.92);
    color:         {{colors.fg}};
    border:        2px solid {{colors.accent}};
    border-radius: 12px;
}

/* ── Start menu launcher ────────────────────────────────── */
#custom-launcher {
    color:            {{colors.accent}};
    font-size:        18px;
    font-weight:      bold;
    padding:          0 14px;
    margin:           4px 4px 4px 6px;
    background:       rgba({{colors.accent_rgb}}, 0.18);
    background-image: none;
    border-radius:    8px;
    box-shadow:       none;
    transition:       all 0.15s ease;
}

#custom-launcher:hover {
    background:       rgba({{colors.accent_rgb}}, 0.40);
    background-image: none;
    color:            {{colors.fg}};
    box-shadow:       none;
}

/* ── Workspaces ─────────────────────────────────────────── */
#workspaces button {
    padding:          2px 12px;
    background:       transparent;
    background-image: none;
    color:            {{colors.muted}};
    border:           none;
    border-radius:    8px;
    margin:           4px 2px;
    box-shadow:       none;
    transition:       all 0.15s ease;
}

#workspaces button.focused {
    background:       {{colors.accent}};
    background-image: none;
    color:            {{colors.bg}};
    font-weight:      bold;
    box-shadow:       none;
}

#workspaces button.urgent {
    background:       {{colors.accent_2}};
    background-image: none;
    color:            {{colors.fg}};
    box-shadow:       none;
}

#workspaces button:hover {
    background:       rgba({{colors.accent_rgb}}, 0.30);
    background-image: none;
    color:            {{colors.fg}};
    box-shadow:       none;
    border:           none;
    text-shadow:      none;
}

#workspaces button.focused:hover {
    background:       #ffb3d1;
    color:            {{colors.bg}};
}

/* ── Window title ───────────────────────────────────────── */
#window {
    color:       {{colors.ok}};
    font-style:  italic;
    padding:     0 8px;
}

/* ── Clock ──────────────────────────────────────────────── */
#clock {
    color:       {{colors.accent}};
    font-weight: bold;
    font-size:   14px;
    padding:     0 12px;
}

/* ── Notes ──────────────────────────────────────────────── */
#custom-notes {
    color:   {{colors.accent}};
    padding: 0 10px;
}

/* ── Weather ────────────────────────────────────────────── */
#custom-weather {
    color:   {{colors.ok}};
    padding: 0 10px;
}

#custom-weather.weather-error {
    color: {{colors.muted}};
}

/* ── Pulseaudio ─────────────────────────────────────────── */
#pulseaudio {
    color:   {{colors.ok}};
    padding: 0 12px;
}

#pulseaudio.muted {
    color: #555555;
}

/* ── Tray ───────────────────────────────────────────────── */
#tray {
    padding: 0 8px;
}

#tray > .passive {
    -gtk-icon-effect: dim;
}
```

Note: the lighter pink hover color (`#ffb3d1`) and the darkened-muted (`#555555`) are kept literal — they are tints of the accent / muted that don't have a palette slot, and inventing new slots just for them is YAGNI.

- [ ] **Step 7: Write `templates/mako.config.tmpl`**

Copy of `config/mako/config` with palette substitutions:

```
font=Noto Sans 11
background-color={{colors.bg_alt}}ee
text-color={{colors.fg}}
border-color={{colors.accent}}
progress-color=over {{colors.accent_2}}

border-radius=12
border-size=2
padding=10,14
margin=8

anchor=top-right
max-icon-size=36
icon-path=/usr/share/icons/Papirus

default-timeout=5000
ignore-timeout=0

[urgency=low]
border-color={{colors.ok}}
default-timeout=3000

[urgency=high]
border-color={{colors.accent_2}}
default-timeout=0
```

- [ ] **Step 8: Write `templates/foot.ini.tmpl`**

Foot's `[colors-dark]` block has many ANSI slots; we templatize only the ones tied to palette identity (background, foreground, selection, cursor, and the matching regular slots). The rest stay literal so terminal output keeps standard ANSI semantics across themes.

```
[main]
font=JetBrains Mono:size=13
pad=14x10 center

[cursor]
blink=yes
blink-rate=500

[mouse]
hide-when-typing=yes

[colors-dark]
# dark purple background, off-white foreground
alpha=0.85
background={{colors.bg_hex}}
foreground={{colors.fg_hex}}

# Normal colors
regular0={{colors.bg_hex}}
regular1={{colors.accent_2_hex}}
regular2={{colors.ok_hex}}
regular3=f1fa8c
regular4=80cfa9
regular5={{colors.accent_hex}}
regular6=8be9fd
regular7={{colors.fg_hex}}

# Bright colors
bright0=44475a
bright1=ff5555
bright2=b8f0c8
bright3=ffffa5
bright4=a4d8ff
bright5=ffb3d1
bright6=a4ffff
bright7=ffffff

selection-background={{colors.accent_hex}}
selection-foreground={{colors.bg_hex}}

cursor={{colors.bg_hex}} {{colors.accent_hex}}

[key-bindings]
clipboard-copy=Control+Shift+c
clipboard-paste=Control+Shift+v
font-increase=Control+equal
font-decrease=Control+minus
font-reset=Control+0
```

- [ ] **Step 9: Write the byte-equivalence test `tests/test_theme_templates.py`**

```python
import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]    # repo root
CP = ROOT / "config" / "control-panel"


def _load(name):
    return json.loads((CP / "themes" / f"{name}.json").read_text())


@pytest.mark.parametrize("template,live", [
    ("rofi.theme.rasi.tmpl",     ROOT / "config/rofi/theme.rasi"),
    ("waybar.style.css.tmpl",    ROOT / "config/waybar/style.css"),
    ("mako.config.tmpl",         ROOT / "config/mako/config"),
    ("foot.ini.tmpl",            ROOT / "config/foot/foot.ini"),
])
def test_pink_green_renders_byte_equivalent_to_live_config(template, live):
    from _theme_render import render_file
    rendered = render_file(CP / "templates" / template, _load("pink-green"))
    actual = live.read_text()
    assert rendered == actual, (
        f"\n--- TEMPLATE OUTPUT ---\n{rendered}\n"
        f"--- LIVE FILE ---\n{actual}\n"
    )


@pytest.mark.parametrize("name", ["pink-green", "blue-cyan", "amber-violet"])
def test_every_template_renders_with_every_palette(name):
    from _theme_render import render_file
    for tmpl in (CP / "templates").glob("*.tmpl"):
        out = render_file(tmpl, _load(name))
        assert "{{" not in out, f"unsubstituted placeholder in {tmpl} for {name}"
```

- [ ] **Step 10: Run tests; iterate until all four byte-equivalent**

```bash
cd config/control-panel
python -m pytest tests/test_theme_templates.py -v
```
Expected: 7 passed (4 byte-equivalence + 3 every-palette).

If a byte-equivalence test fails, the diff in the assertion message points at the discrepancy: usually a stray space, alpha-suffix, or palette-color you missed templatizing. Fix the template until it matches exactly.

- [ ] **Step 11: Commit**

```bash
git add config/control-panel/themes config/control-panel/templates \
        config/control-panel/_theme_render.py \
        config/control-panel/tests/test_theme_templates.py
git commit -m "Add theme palettes, templates, and byte-equivalence tests

Three preset palettes (pink-green, blue-cyan, amber-violet) and
templatized rofi/waybar/mako/foot configs. Tests verify the pink-green
preset renders byte-equivalent to the live configs so templatization
introduces no semantic drift."
```

---

## Task 6: Theme handler

API for listing/applying/reverting themes. Apply pipeline: backup → render templates → write into `~/.config/{rofi,waybar,mako,foot}/` → reload daemons. Daemon reloads gated by `CONTROL_PANEL_SKIP_RELOAD` so tests don't shell out.

**Files:**
- Create: `config/control-panel/handlers/theme.py`
- Create: `config/control-panel/tests/test_theme.py`

- [ ] **Step 1: Write the failing tests**

`config/control-panel/tests/test_theme.py`:

```python
import json
import shutil
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
CP = ROOT / "config" / "control-panel"


@pytest.fixture
def theme(tmp_path, monkeypatch):
    home = tmp_path / "home"
    home.mkdir()
    state = home / ".config" / "control-panel"
    state.mkdir(parents=True)
    targets = home / ".config"
    for sub in ("rofi", "waybar", "mako", "foot"):
        (targets / sub).mkdir()

    monkeypatch.setenv("CONTROL_PANEL_THEMES_DIR", str(CP / "themes"))
    monkeypatch.setenv("CONTROL_PANEL_TEMPLATES_DIR", str(CP / "templates"))
    monkeypatch.setenv("CONTROL_PANEL_STATE_DIR", str(state))
    monkeypatch.setenv("CONTROL_PANEL_TARGETS_DIR", str(targets))
    monkeypatch.setenv("CONTROL_PANEL_SKIP_RELOAD", "1")

    import importlib
    import handlers.theme as m
    importlib.reload(m)
    return m, home


def test_list_includes_three_presets(theme):
    mod, _ = theme
    status, body = mod.handle("GET", "list", None)
    assert status == 200
    names = sorted(p["name"] for p in body)
    assert names == ["amber-violet", "blue-cyan", "pink-green"]


def test_current_initially_none(theme):
    mod, _ = theme
    status, body = mod.handle("GET", "current", None)
    assert status == 200 and body["name"] is None


def test_apply_writes_target_files_and_records_current(theme):
    mod, home = theme
    status, body = mod.handle("POST", "apply", {"name": "pink-green"})
    assert status == 200 and body == {"ok": True}

    rofi = (home / ".config/rofi/theme.rasi").read_text()
    assert "{{" not in rofi
    assert "#1e1b2e" in rofi or "@bg" in rofi   # bg present somewhere

    waybar = (home / ".config/waybar/style.css").read_text()
    assert "rgba(30, 27, 46, 0.92)" in waybar    # pink-green bg_rgb

    mako = (home / ".config/mako/config").read_text()
    assert "background-color=#2d2b3dee" in mako

    foot = (home / ".config/foot/foot.ini").read_text()
    assert "background=1e1b2e" in foot

    cur = json.loads((home / ".config/control-panel/theme.current.json")
                     .read_text())
    assert cur["name"] == "pink-green"


def test_apply_unknown_palette_404(theme):
    from handlers._safe import HandlerError
    mod, _ = theme
    with pytest.raises(HandlerError) as exc:
        mod.handle("POST", "apply", {"name": "no-such"})
    assert exc.value.status == 404


def test_revert_restores_previous(theme):
    mod, home = theme
    mod.handle("POST", "apply", {"name": "pink-green"})
    mod.handle("POST", "apply", {"name": "blue-cyan"})

    foot = (home / ".config/foot/foot.ini").read_text()
    assert "background=0f1729" in foot   # blue-cyan bg

    status, body = mod.handle("POST", "revert", None)
    assert status == 200
    assert body["name"] == "pink-green"

    foot = (home / ".config/foot/foot.ini").read_text()
    assert "background=1e1b2e" in foot   # back to pink-green


def test_revert_with_no_history_409(theme):
    from handlers._safe import HandlerError
    mod, _ = theme
    with pytest.raises(HandlerError) as exc:
        mod.handle("POST", "revert", None)
    assert exc.value.status == 409
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd config/control-panel
python -m pytest tests/test_theme.py -v
```
Expected: ModuleNotFoundError on `handlers.theme`.

- [ ] **Step 3: Implement `handlers/theme.py`**

`config/control-panel/handlers/theme.py`:

```python
"""Theme panel backend.

Applies a named palette by rendering each .tmpl in TEMPLATES_DIR and writing
the result to the matching file under TARGETS_DIR. Backs up the previous
versions of each target file so `revert` can roll back. Reloads waybar/mako/
sway after each apply unless CONTROL_PANEL_SKIP_RELOAD is set.
"""
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from handlers._safe import HandlerError

# Each tmpl maps to a target relative to ~/.config (or TARGETS_DIR).
TARGET_MAP = {
    "rofi.theme.rasi.tmpl":  "rofi/theme.rasi",
    "waybar.style.css.tmpl": "waybar/style.css",
    "mako.config.tmpl":      "mako/config",
    "foot.ini.tmpl":         "foot/foot.ini",
}


def _root_path(name: str) -> Path:
    """Import _theme_render from the package root regardless of cwd."""
    here = Path(__file__).resolve().parent.parent
    return here / name


def _state_dir() -> Path:
    p = Path(os.environ.get(
        "CONTROL_PANEL_STATE_DIR",
        str(Path.home() / ".config/control-panel")
    ))
    p.mkdir(parents=True, exist_ok=True)
    return p


def _themes_dir() -> Path:
    return Path(os.environ.get(
        "CONTROL_PANEL_THEMES_DIR", str(_root_path("themes"))
    ))


def _templates_dir() -> Path:
    return Path(os.environ.get(
        "CONTROL_PANEL_TEMPLATES_DIR", str(_root_path("templates"))
    ))


def _targets_dir() -> Path:
    return Path(os.environ.get(
        "CONTROL_PANEL_TARGETS_DIR", str(Path.home() / ".config")
    ))


def _backup_root() -> Path:
    p = _state_dir() / "backup"
    p.mkdir(exist_ok=True)
    return p


def _load_palette(name: str) -> dict:
    f = _themes_dir() / f"{name}.json"
    if not f.is_file():
        raise HandlerError(404, f"unknown palette: {name}")
    return json.loads(f.read_text())


def _list():
    out = []
    for f in sorted(_themes_dir().glob("*.json")):
        try:
            out.append(json.loads(f.read_text()))
        except json.JSONDecodeError:
            continue
    return out


def _current_path() -> Path:
    return _state_dir() / "theme.current.json"


def _current():
    f = _current_path()
    if not f.is_file():
        return {"name": None, "colors": None}
    data = json.loads(f.read_text())
    return {"name": data.get("name"), "colors": data.get("colors")}


def _renderer():
    # Imported lazily so tests that don't touch templating don't pay for it.
    sys.path.insert(0, str(_root_path("")))
    import _theme_render
    return _theme_render


def _backup_current_targets() -> Path:
    stamp = time.strftime("%Y%m%dT%H%M%S")
    bdir = _backup_root() / stamp
    bdir.mkdir(parents=True)
    for tmpl, rel in TARGET_MAP.items():
        src = _targets_dir() / rel
        if src.is_file():
            dst = bdir / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
    cur = _current_path()
    if cur.is_file():
        shutil.copy2(cur, bdir / "theme.current.json")
    return bdir


def _restore_from(bdir: Path):
    for tmpl, rel in TARGET_MAP.items():
        src = bdir / rel
        if src.is_file():
            dst = _targets_dir() / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
    saved = bdir / "theme.current.json"
    if saved.is_file():
        shutil.copy2(saved, _current_path())
    else:
        if _current_path().is_file():
            _current_path().unlink()


def _reload_daemons():
    if os.environ.get("CONTROL_PANEL_SKIP_RELOAD"):
        return
    subprocess.run(["swaymsg", "reload"], check=False)
    subprocess.run(["pkill", "-SIGUSR2", "waybar"], check=False)
    subprocess.run(["pkill", "-SIGUSR1", "mako"], check=False)


def _apply(name: str):
    palette = _load_palette(name)
    bdir = _backup_current_targets()
    render = _renderer().render_file
    for tmpl_name, rel in TARGET_MAP.items():
        tmpl = _templates_dir() / tmpl_name
        if not tmpl.is_file():
            continue
        out = render(tmpl, palette)
        target = _targets_dir() / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(out)
    _current_path().write_text(json.dumps(palette, indent=2))
    _reload_daemons()


def _revert():
    backups = sorted([p for p in _backup_root().iterdir() if p.is_dir()])
    if not backups:
        raise HandlerError(409, "no backups to revert to")
    latest = backups[-1]
    _restore_from(latest)
    shutil.rmtree(latest)
    _reload_daemons()
    cur = _current()
    return cur["name"]


def handle(method, subpath, body):
    if method == "GET" and subpath == "list":
        return 200, _list()
    if method == "GET" and subpath == "current":
        return 200, _current()
    if method == "POST" and subpath == "apply":
        body = body or {}
        name = body.get("name") or ""
        _apply(name)
        return 200, {"ok": True}
    if method == "POST" and subpath == "revert":
        name = _revert()
        return 200, {"ok": True, "name": name}
    raise HandlerError(404, f"unknown route: {method} {subpath}")
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd config/control-panel
python -m pytest tests/test_theme.py -v
```
Expected: 6 passed.

- [ ] **Step 5: Run the full backend test suite**

```bash
cd config/control-panel
python -m pytest -v
```
Expected: all tests pass (safe + server + notes + wallpaper + theme_templates + theme).

- [ ] **Step 6: Commit**

```bash
git add config/control-panel/handlers/theme.py config/control-panel/tests/test_theme.py
git commit -m "Add theme handler with apply/revert pipeline

Renders the four templates against the chosen palette, backs up the
previous configs into ~/.config/control-panel/backup/<ts>/ for revert,
and signals waybar/mako/sway to reload (skipped under
CONTROL_PANEL_SKIP_RELOAD=1 for tests)."
```

---

## Task 7: Frontend shell — index.html, app.js, styles.css

The HTML shell, the panel router, and the host stylesheet.

**Files:**
- Create: `config/control-panel/web/index.html`
- Create: `config/control-panel/web/app.js`
- Create: `config/control-panel/web/styles.css`

- [ ] **Step 1: Write `web/index.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Control Panel</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <aside id="sidebar">
    <h1>Control Panel</h1>
    <nav id="nav"></nav>
  </aside>
  <main id="content"></main>
  <div id="toasts"></div>

  <script type="module" src="/app.js"></script>
</body>
</html>
```

- [ ] **Step 2: Write `web/styles.css`**

```css
:root {
  --bg:        #1e1b2e;
  --bg-alt:    #2d2b3d;
  --fg:        #f8f8f2;
  --accent:    #f48fb1;
  --accent-2:  #e91e8c;
  --ok:        #a8d8a8;
  --muted:     #888888;
}

* { box-sizing: border-box; }

html, body {
  margin: 0;
  height: 100%;
  font-family: "Noto Sans", system-ui, sans-serif;
  background: var(--bg);
  color: var(--fg);
}

body {
  display: grid;
  grid-template-columns: 220px 1fr;
}

#sidebar {
  background: var(--bg-alt);
  padding: 18px 14px;
  border-right: 1px solid rgba(255,255,255,0.05);
}

#sidebar h1 {
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--accent);
  margin: 0 0 18px 4px;
}

#nav {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-link {
  background: transparent;
  border: 0;
  color: var(--fg);
  text-align: left;
  padding: 8px 10px;
  border-radius: 6px;
  cursor: pointer;
  font: inherit;
  display: flex;
  gap: 10px;
  align-items: center;
}

.nav-link:hover { background: rgba(244,143,177,0.18); }
.nav-link.active {
  background: var(--accent);
  color: var(--bg);
  font-weight: bold;
}

#content {
  padding: 28px;
  overflow: auto;
}

.panel-h2 {
  margin-top: 0;
  color: var(--accent);
}

button {
  background: var(--accent);
  color: var(--bg);
  border: 0;
  border-radius: 6px;
  padding: 6px 14px;
  cursor: pointer;
  font: inherit;
  font-weight: bold;
}
button:hover { background: var(--accent-2); color: var(--fg); }
button.ghost {
  background: transparent;
  color: var(--fg);
  border: 1px solid var(--muted);
}

input, textarea {
  background: var(--bg-alt);
  color: var(--fg);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 6px;
  padding: 6px 8px;
  font: inherit;
}

#toasts {
  position: fixed;
  right: 16px;
  bottom: 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  z-index: 100;
}
.toast {
  background: var(--bg-alt);
  border-left: 3px solid var(--accent);
  padding: 10px 14px;
  border-radius: 4px;
  min-width: 200px;
}
.toast.error { border-left-color: var(--accent-2); }
.toast.success { border-left-color: var(--ok); }
```

- [ ] **Step 3: Write `web/app.js`**

```js
// Panel router. Imports panels via /panels/index.js (auto-generated by the
// server at startup) and renders the one matching window.location.hash.

import panels from "/panels/index.js";

const byId = Object.fromEntries(panels.map(p => [p.id, p]));

function makeApi(panelId) {
  const base = `/api/${panelId}`;
  async function jsonOrThrow(resp) {
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok) throw new Error(data.error || resp.statusText);
    return data;
  }
  return {
    get: (sub) => fetch(`${base}/${sub}`).then(jsonOrThrow),
    post: (sub, body) => fetch(`${base}/${sub}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body || {}),
    }).then(jsonOrThrow),
    notify,
    confirm: (msg) => Promise.resolve(window.confirm(msg)),
  };
}

function notify(msg, kind = "info") {
  const div = document.createElement("div");
  div.className = `toast ${kind}`;
  div.textContent = msg;
  document.getElementById("toasts").appendChild(div);
  setTimeout(() => div.remove(), 3500);
}

const nav = document.getElementById("nav");
const content = document.getElementById("content");

const sorted = panels.slice().sort(
  (a, b) => (a.order ?? 99) - (b.order ?? 99)
);

for (const p of sorted) {
  const btn = document.createElement("button");
  btn.className = "nav-link";
  btn.dataset.id = p.id;
  btn.innerHTML = `<span>${p.icon || ""}</span><span>${p.title}</span>`;
  btn.onclick = () => { window.location.hash = p.id; };
  nav.appendChild(btn);
}

let currentId = null;
async function route() {
  const id = (window.location.hash || "").replace("#", "")
    || sorted[0]?.id || null;
  if (!id || !byId[id]) {
    content.innerHTML = "<p>No panel selected.</p>";
    return;
  }
  if (currentId && byId[currentId]?.unmount) {
    byId[currentId].unmount(content);
  }
  content.innerHTML = "";
  for (const btn of nav.querySelectorAll(".nav-link")) {
    btn.classList.toggle("active", btn.dataset.id === id);
  }
  try {
    await byId[id].mount(content, makeApi(id));
  } catch (e) {
    console.error(e);
    notify("panel failed to load: " + e.message, "error");
  }
  currentId = id;
}

window.addEventListener("hashchange", route);
route();
```

- [ ] **Step 4: Smoke check the shell**

There's no automated frontend test in v1. Manual check:

```bash
cd config/control-panel
python server.py --port 8765 &
SERVER_PID=$!
sleep 0.5
curl -s http://127.0.0.1:8765/ | grep -q "Control Panel" && echo OK
curl -s http://127.0.0.1:8765/api/_panels | python -m json.tool
kill $SERVER_PID
```
Expected: `OK` printed, `/api/_panels` returns a JSON array (panels list will be empty until Tasks 8–10 add the JS modules).

- [ ] **Step 5: Commit**

```bash
git add config/control-panel/web/index.html \
        config/control-panel/web/app.js \
        config/control-panel/web/styles.css
git commit -m "Add frontend shell: sidebar nav, panel router, host styles

Loads panels via /panels/index.js (auto-generated by the server) and
routes between them via window.location.hash. Each panel receives a
namespaced api object so it cannot accidentally hit another panel's
backend."
```

---

## Task 8: Notes panel (frontend)

**Files:**
- Create: `config/control-panel/web/panels/notes.js`

- [ ] **Step 1: Write `web/panels/notes.js`**

```js
const fmtTime = (epoch) => {
  const d = new Date(epoch * 1000);
  return d.toLocaleString();
};

let state = { notes: [], selected: null, dirty: false, saveTimer: null };

async function refreshList(api) {
  state.notes = await api.get("list");
  renderList();
}

function renderList() {
  const list = document.getElementById("notes-list");
  list.innerHTML = "";
  for (const n of state.notes) {
    const li = document.createElement("li");
    li.className = "notes-item" + (n.id === state.selected ? " active" : "");
    li.innerHTML = `<div class="notes-title">${
      escapeHTML(n.title)
    }</div><div class="notes-mtime">${fmtTime(n.mtime)}</div>`;
    li.onclick = () => loadNote(n.id);
    list.appendChild(li);
  }
}

function escapeHTML(s) {
  return s.replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

async function loadNote(id) {
  if (state.dirty && !confirm("Discard unsaved changes?")) return;
  if (id === null) {
    state.selected = null;
    document.getElementById("notes-title").value = "";
    document.getElementById("notes-body").value = "";
  } else {
    const n = await api.get(`get/${id}`);
    state.selected = id;
    document.getElementById("notes-title").value = n.title;
    document.getElementById("notes-body").value = n.body;
  }
  state.dirty = false;
  renderList();
}

let api;

async function save() {
  const title = document.getElementById("notes-title").value;
  const body = document.getElementById("notes-body").value;
  const payload = { title, body };
  if (state.selected) payload.id = state.selected;
  const res = await api.post("save", payload);
  state.selected = res.id;
  state.dirty = false;
  api.notify("Saved", "success");
  await refreshList(api);
}

async function del() {
  if (!state.selected) return;
  if (!await api.confirm("Delete this note?")) return;
  await api.post(`delete/${state.selected}`, {});
  state.selected = null;
  document.getElementById("notes-title").value = "";
  document.getElementById("notes-body").value = "";
  state.dirty = false;
  await refreshList(api);
}

function scheduleSave() {
  state.dirty = true;
  if (state.saveTimer) clearTimeout(state.saveTimer);
  state.saveTimer = setTimeout(() => save().catch(e =>
    api.notify("Save failed: " + e.message, "error")
  ), 1000);
}

export default {
  id: "notes",
  title: "Notes",
  icon: "📝",
  order: 10,
  mount(root, _api) {
    api = _api;
    root.innerHTML = `
      <h2 class="panel-h2">Notes</h2>
      <div class="notes-grid">
        <div class="notes-side">
          <div class="notes-actions">
            <button id="notes-new">New</button>
            <button id="notes-save" class="ghost">Save</button>
            <button id="notes-delete" class="ghost">Delete</button>
          </div>
          <ul id="notes-list"></ul>
        </div>
        <div class="notes-edit">
          <input id="notes-title" placeholder="Title" />
          <textarea id="notes-body" placeholder="Body…"></textarea>
        </div>
      </div>
      <style>
        .notes-grid { display: grid; grid-template-columns: 280px 1fr;
                      gap: 16px; }
        .notes-actions { display: flex; gap: 6px; margin-bottom: 10px; }
        ul#notes-list { list-style: none; padding: 0; margin: 0;
                        display: flex; flex-direction: column; gap: 4px; }
        .notes-item { padding: 8px 10px; border-radius: 6px;
                      background: var(--bg-alt); cursor: pointer; }
        .notes-item.active { background: var(--accent); color: var(--bg); }
        .notes-title { font-weight: bold; }
        .notes-mtime { font-size: 11px; color: var(--muted); }
        .notes-item.active .notes-mtime { color: var(--bg); opacity: 0.7; }
        .notes-edit { display: flex; flex-direction: column; gap: 8px; }
        #notes-body { min-height: 380px; font-family: monospace; }
      </style>`;

    document.getElementById("notes-new").onclick = () => loadNote(null);
    document.getElementById("notes-save").onclick = () =>
      save().catch(e => api.notify("Save failed: " + e.message, "error"));
    document.getElementById("notes-delete").onclick = () =>
      del().catch(e => api.notify("Delete failed: " + e.message, "error"));
    document.getElementById("notes-title").addEventListener(
      "input", scheduleSave);
    document.getElementById("notes-body").addEventListener(
      "input", scheduleSave);
    window.addEventListener("keydown", keydown);
    refreshList(api);
  },
  unmount(root) {
    if (state.saveTimer) clearTimeout(state.saveTimer);
    state = { notes: [], selected: null, dirty: false, saveTimer: null };
    window.removeEventListener("keydown", keydown);
  },
};

function keydown(e) {
  if (e.ctrlKey && e.key === "s") {
    e.preventDefault();
    save().catch(err => api.notify("Save failed: " + err.message, "error"));
  }
}
```

- [ ] **Step 2: Smoke check**

```bash
cd config/control-panel
python server.py --port 8765 &
SERVER_PID=$!
sleep 0.5
curl -s http://127.0.0.1:8765/api/_panels | python -m json.tool
# Should now include {"id": "notes"} (server regenerates panels/index.js)
kill $SERVER_PID
```

- [ ] **Step 3: Commit**

```bash
git add config/control-panel/web/panels/notes.js
git commit -m "Add notes panel (frontend)

Two-pane editor: list of notes on the left, title+body editor on the
right. Saves on Ctrl+S, on the Save button, and after 1 second of
typing inactivity. Deletes go through api.confirm."
```

---

## Task 9: Wallpaper panel (frontend)

**Files:**
- Create: `config/control-panel/web/panels/wallpaper.js`

- [ ] **Step 1: Write `web/panels/wallpaper.js`**

```js
let api, current = null, items = [];

function escapeHTML(s) {
  return s.replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

async function refresh() {
  const dirRes = await api.get("dir");
  document.getElementById("wp-dir").value = dirRes.path;
  current = (await api.get("current")).name;
  items = await api.get("list");
  renderGrid();
}

function renderGrid() {
  const grid = document.getElementById("wp-grid");
  grid.innerHTML = "";
  for (const it of items) {
    const card = document.createElement("button");
    card.className = "wp-card" + (it.name === current ? " active" : "");
    // The thumb endpoint isn't implemented in v1 — we just display the
    // filename. (Adding ImageMagick-backed thumbs is a follow-up.)
    card.innerHTML = `<div class="wp-name">${escapeHTML(it.name)}</div>`;
    card.onclick = () => apply(it.name);
    grid.appendChild(card);
  }
}

async function apply(name) {
  try {
    await api.post("set", { name });
    current = name;
    api.notify(`Wallpaper set: ${name}`, "success");
    renderGrid();
  } catch (e) {
    api.notify("Failed: " + e.message, "error");
  }
}

async function setDir() {
  const path = document.getElementById("wp-dir").value;
  try {
    await api.post("dir", { path });
    api.notify("Source directory updated", "success");
    refresh();
  } catch (e) {
    api.notify("Failed: " + e.message, "error");
  }
}

export default {
  id: "wallpaper",
  title: "Wallpaper",
  icon: "🖼️",
  order: 20,
  mount(root, _api) {
    api = _api;
    root.innerHTML = `
      <h2 class="panel-h2">Wallpaper</h2>
      <div class="wp-dir-row">
        <label for="wp-dir">Source folder</label>
        <input id="wp-dir" />
        <button id="wp-dir-set">Set</button>
      </div>
      <div id="wp-grid"></div>
      <style>
        .wp-dir-row { display: flex; gap: 8px; align-items: center;
                      margin-bottom: 16px; }
        .wp-dir-row input { flex: 1; }
        #wp-grid { display: grid; gap: 10px;
                   grid-template-columns: repeat(auto-fill,
                                                  minmax(180px, 1fr)); }
        .wp-card { background: var(--bg-alt); border: 1px solid transparent;
                   color: var(--fg); padding: 10px; border-radius: 8px;
                   cursor: pointer; text-align: left; }
        .wp-card:hover { border-color: var(--accent); }
        .wp-card.active { border-color: var(--accent); background: var(--accent);
                          color: var(--bg); }
        .wp-name { font-size: 12px; word-break: break-all; }
      </style>`;
    document.getElementById("wp-dir-set").onclick = setDir;
    refresh();
  },
  unmount() { items = []; current = null; },
};
```

- [ ] **Step 2: Commit**

```bash
git add config/control-panel/web/panels/wallpaper.js
git commit -m "Add wallpaper panel (frontend)

Lists images from the configured source folder, lets the user click to
apply, and exposes a folder-picker for changing the source directory.
Thumbnails deferred — v1 shows filenames only."
```

---

## Task 10: Theme panel (frontend)

**Files:**
- Create: `config/control-panel/web/panels/theme.js`

- [ ] **Step 1: Write `web/panels/theme.js`**

```js
let api, current = null, presets = [];

async function refresh() {
  presets = await api.get("list");
  current = (await api.get("current")).name;
  render();
}

function render() {
  const grid = document.getElementById("theme-grid");
  grid.innerHTML = "";
  for (const p of presets) {
    const card = document.createElement("button");
    card.className = "theme-card" + (p.name === current ? " active" : "");
    const swatches = ["bg", "bg_alt", "fg", "accent", "accent_2",
                      "ok", "muted"]
      .map(slot => `<span class="swatch" style="background:${
        p.colors[slot]
      }"></span>`).join("");
    card.innerHTML = `<div class="swatches">${
      swatches}</div><div class="theme-label">${
      p.label}</div>`;
    card.onclick = () => apply(p.name);
    grid.appendChild(card);
  }
}

async function apply(name) {
  try {
    await api.post("apply", { name });
    current = name;
    api.notify(`Applied: ${name}`, "success");
    render();
  } catch (e) { api.notify("Failed: " + e.message, "error"); }
}

async function revert() {
  try {
    const res = await api.post("revert", {});
    current = res.name;
    api.notify(`Reverted to: ${current}`, "success");
    render();
  } catch (e) { api.notify("Revert failed: " + e.message, "error"); }
}

export default {
  id: "theme",
  title: "Theme",
  icon: "🎨",
  order: 30,
  mount(root, _api) {
    api = _api;
    root.innerHTML = `
      <h2 class="panel-h2">Color Theme</h2>
      <p>Pick a palette. Applies to rofi, waybar, mako, foot.
         Already-open foot windows keep their old colors.</p>
      <div id="theme-grid"></div>
      <div style="margin-top:16px;">
        <button id="theme-revert" class="ghost">Revert last apply</button>
      </div>
      <style>
        #theme-grid { display: grid; gap: 12px;
                      grid-template-columns: repeat(auto-fill,
                                                     minmax(220px, 1fr)); }
        .theme-card { background: var(--bg-alt); color: var(--fg);
                      border: 2px solid transparent; border-radius: 10px;
                      padding: 14px; cursor: pointer; text-align: left; }
        .theme-card:hover { border-color: var(--accent); }
        .theme-card.active { border-color: var(--accent); }
        .swatches { display: flex; gap: 4px; margin-bottom: 8px; }
        .swatch { width: 20px; height: 20px; border-radius: 50%;
                  border: 1px solid rgba(255,255,255,0.1); }
        .theme-label { font-weight: bold; }
      </style>`;
    document.getElementById("theme-revert").onclick = revert;
    refresh();
  },
  unmount() { presets = []; current = null; },
};
```

- [ ] **Step 2: Smoke check the full panel set**

```bash
cd config/control-panel
python server.py --port 8765 &
SERVER_PID=$!
sleep 0.5
curl -s http://127.0.0.1:8765/api/_panels | python -m json.tool
# Expect: [{"id":"notes"}, {"id":"theme"}, {"id":"wallpaper"}]
kill $SERVER_PID
```

- [ ] **Step 3: Commit**

```bash
git add config/control-panel/web/panels/theme.js
git commit -m "Add theme panel (frontend)

Swatch grid for the three preset palettes; click applies (writes target
configs and reloads daemons via the backend), revert button rolls back
the previous apply."
```

---

## Task 11: `launch.sh` + waybar / sway / setup integration

Wire the panel into the existing system: a launcher shell script, a waybar button, a sway keybind, and the setup script's directory creation.

**Files:**
- Create: `config/control-panel/launch.sh`
- Modify: `config/waybar/config.jsonc`
- Modify: `config/waybar/style.css` (add small style for the new icon)
- Modify: `config/sway/config` (one new keybind line)
- Modify: `setup.sh` (chmod + mkdir)

- [ ] **Step 1: Write `config/control-panel/launch.sh`**

```bash
#!/bin/bash
# control-panel launcher: starts the python server on a free loopback port,
# opens chromium in --app= mode, and tears the server down on exit.
#
# Falls back to xdg-open if chromium isn't on PATH.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"

# Pick a free port (Python figures it out for us).
PORT=$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(('127.0.0.1', 0))
print(s.getsockname()[1])
s.close()
PY
)

cleanup() {
    [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

python3 "$DIR/server.py" --host 127.0.0.1 --port "$PORT" &
SERVER_PID=$!

# Wait for the server to come up (max ~2 s).
for _ in $(seq 1 20); do
    if curl -s "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

URL="http://127.0.0.1:$PORT/"
if command -v chromium >/dev/null 2>&1; then
    chromium --app="$URL"
elif command -v google-chrome >/dev/null 2>&1; then
    google-chrome --app="$URL"
else
    xdg-open "$URL"
    # Browser may detach; keep the server alive until the user kills the script.
    wait "$SERVER_PID"
fi
```

- [ ] **Step 2: Modify `config/waybar/config.jsonc` — add `custom/control-panel`**

Replace the `modules-right` line and append a new module block.

Old `modules-right`:
```jsonc
    "modules-right":  ["custom/notes", "custom/weather", "sway/language", "pulseaudio", "tray"],
```

New `modules-right`:
```jsonc
    "modules-right":  ["custom/control-panel", "custom/notes", "custom/weather", "sway/language", "pulseaudio", "tray"],
```

Add this block (anywhere in the object — between `custom/weather` and `sway/language` is a good spot):

```jsonc
    "custom/control-panel": {
        "format":   "⚙",
        "tooltip":  "Open control panel",
        "on-click": "$HOME/.config/control-panel/launch.sh"
    },
```

- [ ] **Step 3: Modify `config/waybar/style.css` — add styling for `#custom-control-panel`**

Add this block somewhere in the file (the `/* ── Notes ── */` block is a good neighbour):

```css
/* ── Control panel ──────────────────────────────────────── */
#custom-control-panel {
    color:   #f48fb1;
    padding: 0 10px;
}
```

(Yes, hex literal — `style.css` is the templated source-of-truth file, but this addition is being made *to the live file directly*. We'll templatize it in a follow-up after first apply confirms templates still match. Keep it as `#f48fb1` to stay byte-equivalent for the templates.)

Wait — this would break the byte-equivalence test from Task 5. Two options:

  - (a) Update `templates/waybar.style.css.tmpl` in the same step so the rendered output keeps matching the live file.
  - (b) Defer the new icon styling to a post-Task-5 follow-up.

Use **(a)**: also append the same block (with `{{colors.accent}}` for the color) to `config/control-panel/templates/waybar.style.css.tmpl` so the test stays green. Re-run `pytest tests/test_theme_templates.py -v` after the edit.

So the *template* gets:
```css
/* ── Control panel ──────────────────────────────────────── */
#custom-control-panel {
    color:   {{colors.accent}};
    padding: 0 10px;
}
```

…and the live `style.css` gets the same block but with `#f48fb1`.

- [ ] **Step 4: Modify `config/sway/config` — add the keybind**

Find the `# Utilities:` block (around line 165). Append (after the `bindsym Print exec grim` line):

```
    # Control panel (web-based settings)
    bindsym $mod+Shift+s exec ~/.config/control-panel/launch.sh
```

- [ ] **Step 5: Modify `setup.sh` — make scripts executable, create state dirs**

Read `setup.sh` first to see its existing structure, then add commands consistent with what's already there. The minimum additions:

```bash
chmod +x "$REPO/config/control-panel/launch.sh"
chmod +x "$REPO/config/control-panel/server.py"
mkdir -p "$HOME/.config/control-panel"
mkdir -p "$HOME/.cache/control-panel"
```

(Adapt the variable names — `$REPO`, `$DOTFILES`, etc. — to match what `setup.sh` already uses.)

- [ ] **Step 6: Mark `launch.sh` executable in git**

```bash
git update-index --chmod=+x config/control-panel/launch.sh
```

- [ ] **Step 7: Re-run byte-equivalence test (sanity)**

```bash
cd config/control-panel
python -m pytest tests/test_theme_templates.py -v
```
Expected: 7 passed (the new `#custom-control-panel` block matches between template and live file).

- [ ] **Step 8: Commit**

```bash
git add config/control-panel/launch.sh \
        config/waybar/config.jsonc \
        config/waybar/style.css \
        config/control-panel/templates/waybar.style.css.tmpl \
        config/sway/config \
        setup.sh
git commit -m "Wire control-panel into waybar, sway, and setup

⚙ button in waybar runs launch.sh; \$mod+Shift+s does the same. setup.sh
creates state and cache directories. waybar template kept in sync with
the new icon styling so byte-equivalence holds."
```

---

## Task 12: SMOKE.md + final integration check

Document the manual smoke-test checklist and run it to confirm v1 is shippable.

**Files:**
- Create: `config/control-panel/SMOKE.md`

- [ ] **Step 1: Write `config/control-panel/SMOKE.md`**

```markdown
# Control Panel — Smoke Test Checklist

Run on the deployed Linux box (Areej's machine) after each significant change.
This is the manual verification gate — v1 has no browser-automation tests.

## Setup

- `~/.config/control-panel/` exists and is writable.
- `~/.cache/control-panel/` exists.
- `~/.local/share/waybar-notes/` exists.
- `~/wallpapers/` has at least one .jpg/.png.

## Tests

1. **Launch via icon.** Click ⚙ in waybar → chromium app window opens with the
   sidebar visible. Server log shows `control-panel listening on …`.
2. **Launch via keybind.** Close the window, press `$mod+Shift+s` → same.
3. **Notes panel opens.** Sidebar shows 📝 Notes. Click it.
4. **Add a note.** Click `New`, type a title, type a body, wait 1 second →
   "Saved" toast appears, note shows in left list.
5. **Edit a note.** Click the note in the list, modify body, press Ctrl+S →
   "Saved" toast appears.
6. **Delete a note.** Click `Delete` → confirm prompt → note disappears.
7. **Waybar still rotates notes.** Wait ~30 s and check that the rotating
   waybar 📝 module shows a note title — proves the storage stayed compatible
   with the existing rofi flow.
8. **Wallpaper panel opens.** Sidebar shows 🖼️ Wallpaper.
9. **Apply a wallpaper.** Click a card → "Wallpaper set: …" toast → desktop
   background changes (swaybg gets reloaded).
10. **Theme panel opens.** Sidebar shows 🎨 Theme.
11. **Apply blue-cyan.** Click the blue-cyan swatch card → waybar, mako,
    rofi (next launch), and new foot windows pick up the new colors.
12. **Revert.** Click `Revert last apply` → colors go back to pink-green.
13. **Close window.** Server process exits cleanly (no zombie).

## If anything fails

Run `python -m pytest -v` from `config/control-panel/`. All backend tests
should pass — if they don't, fix there first. Frontend bugs require eyeballing
the browser devtools console.
```

- [ ] **Step 2: Run the full backend test suite once more**

```bash
cd config/control-panel
python -m pytest -v
```
Expected: every test from Tasks 1–6 passes.

- [ ] **Step 3: Manual smoke test on Areej's machine**

Push the branch / sync with the deploy script (whatever the workflow is — see
`deploy.sh`). Then run through `SMOKE.md` step-by-step.

If any item fails: stop, fix, re-test from that step.

- [ ] **Step 4: Commit the smoke checklist**

```bash
git add config/control-panel/SMOKE.md
git commit -m "Add SMOKE.md for control-panel manual verification

13-item checklist run on the deploy box after each significant change.
v1 has no browser-automation tests; this is the gate."
```

---

## Self-Review

**Spec coverage:**
- ✅ Architecture (top-level layout): Tasks 1, 2, 7
- ✅ Runtime flow (launch.sh, port, chromium --app=): Task 11
- ✅ Security model (loopback, safe_join): Task 1
- ✅ Modularity contract (frontend + backend): Tasks 2, 7
- ✅ Notes panel: Tasks 3, 8
- ✅ Wallpaper panel: Tasks 4, 9
- ✅ Theme panel data model + apply pipeline + revert: Tasks 5, 6, 10
- ✅ Templatization byte-equivalence: Task 5
- ✅ Daemon reload (swaymsg / pkill -SIGUSR2 / pkill -SIGUSR1): Task 6
- ✅ Waybar / sway / setup integration: Task 11
- ✅ Tests (backend pure-function + integration + byte-equivalence): Tasks 1–6
- ✅ Smoke checklist: Task 12
- ✅ v1 cut and deferred items match the spec.

**Placeholder scan:** none.

**Type / signature consistency:** every handler exposes `handle(method, subpath, body) → (status, json)` consistently; every panel module exports the same default-object shape (id, title, icon, order, mount, unmount); the `api` object passed to mount has the same surface (get, post, notify, confirm) across all three panels.

**One known mismatch from spec:** notes directory is `~/.local/share/waybar-notes/` (the live path) instead of `~/.local/share/notes/` (what the spec said). Plan uses the live path; spec is wrong on this single detail.
