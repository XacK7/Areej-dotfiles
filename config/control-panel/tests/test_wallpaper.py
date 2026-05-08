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


def test_dir_get_and_set(wp, tmp_path, monkeypatch):
    mod, src, state = wp
    new_src = tmp_path / "other"
    new_src.mkdir()
    (new_src / "z.jpg").write_bytes(b"x")
    # Drop the env override so the dir-file is consulted
    monkeypatch.delenv("CONTROL_PANEL_WALLPAPER_DIR", raising=False)
    status, body = mod.handle("POST", "dir", {"path": str(new_src)})
    assert status == 200
    status, body = mod.handle("GET", "dir", None)
    assert body["path"] == str(new_src)
    status, listing = mod.handle("GET", "list", None)
    assert [i["name"] for i in listing] == ["z.jpg"]
