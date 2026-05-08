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
