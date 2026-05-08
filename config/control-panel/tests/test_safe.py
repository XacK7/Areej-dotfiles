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
