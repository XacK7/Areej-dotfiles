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

# Each tmpl maps to a target relative to TARGETS_DIR (default ~/.config).
TARGET_MAP = {
    "rofi.theme.rasi.tmpl":  "rofi/theme.rasi",
    "waybar.style.css.tmpl": "waybar/style.css",
    "mako.config.tmpl":      "mako/config",
    "foot.ini.tmpl":         "foot/foot.ini",
}


def _root_path(name: str) -> Path:
    """Resolve a path under the control-panel package root."""
    here = Path(__file__).resolve().parent.parent
    return here / name


def _state_dir() -> Path:
    p = Path(os.environ.get(
        "CONTROL_PANEL_STATE_DIR",
        str(Path.home() / ".local/state/control-panel")
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
    return json.loads(f.read_text(encoding="utf-8"))


def _list():
    out = []
    for f in sorted(_themes_dir().glob("*.json")):
        try:
            out.append(json.loads(f.read_text(encoding="utf-8")))
        except json.JSONDecodeError:
            continue
    return out


def _current_path() -> Path:
    return _state_dir() / "theme.current.json"


def _current():
    f = _current_path()
    if not f.is_file():
        return {"name": None, "colors": None}
    data = json.loads(f.read_text(encoding="utf-8"))
    return {"name": data.get("name"), "colors": data.get("colors")}


def _renderer():
    sys.path.insert(0, str(_root_path("")))
    import _theme_render
    return _theme_render


def _backup_current_targets() -> Path:
    # Nanosecond suffix so back-to-back applies always get unique dirs.
    stamp = time.strftime("%Y%m%dT%H%M%S") + f"_{time.time_ns():019d}"
    bdir = _backup_root() / stamp
    bdir.mkdir(parents=True, exist_ok=False)
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
    _backup_current_targets()
    render = _renderer().render_file
    for tmpl_name, rel in TARGET_MAP.items():
        tmpl = _templates_dir() / tmpl_name
        if not tmpl.is_file():
            continue
        out = render(tmpl, palette)
        target = _targets_dir() / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(out, encoding="utf-8")
    _current_path().write_text(json.dumps(palette, indent=2), encoding="utf-8")
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
