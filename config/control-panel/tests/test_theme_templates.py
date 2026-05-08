import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]    # repo root
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
    actual = live.read_text(encoding="utf-8")
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
