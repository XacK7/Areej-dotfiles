"""Wallpaper panel backend.

Lists image files from the configured source directory, tracks the current
selection in a small state file, and (unless CONTROL_PANEL_SKIP_RELOAD is set)
asks swaybg to reload after a change.
"""
import os
import subprocess
from pathlib import Path

from handlers._safe import safe_join, HandlerError

IMG_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def _state_dir() -> Path:
    p = Path(os.environ.get(
        "CONTROL_PANEL_STATE_DIR",
        str(Path.home() / ".local/state/control-panel")
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
