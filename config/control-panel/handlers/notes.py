"""Notes panel backend.

Storage is one .txt file per note in NOTES_DIR. Filename format is
<isoZ-timestamp>-<slug>.txt; first line of the file is the title, rest is the
body. Compatible with the existing waybar rotating-notes script which reads
the same directory.
"""
import os
import re
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
