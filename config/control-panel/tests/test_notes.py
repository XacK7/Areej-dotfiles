import os
from pathlib import Path

import pytest


@pytest.fixture
def notes(tmp_path, monkeypatch):
    monkeypatch.setenv("CONTROL_PANEL_NOTES_DIR", str(tmp_path))
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
