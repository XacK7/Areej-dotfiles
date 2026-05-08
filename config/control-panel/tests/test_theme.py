import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
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

    rofi = (home / ".config/rofi/theme.rasi").read_text(encoding="utf-8")
    assert "{{" not in rofi

    waybar = (home / ".config/waybar/style.css").read_text(encoding="utf-8")
    assert "rgba(30, 27, 46, 0.92)" in waybar

    mako = (home / ".config/mako/config").read_text(encoding="utf-8")
    assert "background-color=#2d2b3dee" in mako

    foot = (home / ".config/foot/foot.ini").read_text(encoding="utf-8")
    assert "background=1e1b2e" in foot

    cur = json.loads((home / ".config/control-panel/theme.current.json")
                     .read_text(encoding="utf-8"))
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

    foot = (home / ".config/foot/foot.ini").read_text(encoding="utf-8")
    assert "background=0f1729" in foot

    status, body = mod.handle("POST", "revert", None)
    assert status == 200
    assert body["name"] == "pink-green"

    foot = (home / ".config/foot/foot.ini").read_text(encoding="utf-8")
    assert "background=1e1b2e" in foot


def test_revert_with_no_history_409(theme):
    from handlers._safe import HandlerError
    mod, _ = theme
    with pytest.raises(HandlerError) as exc:
        mod.handle("POST", "revert", None)
    assert exc.value.status == 409
