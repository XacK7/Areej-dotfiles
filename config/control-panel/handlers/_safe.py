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
