# Control Panel — Smoke Test Checklist

Run on the deployed Linux box (Areej's machine) after each significant change.
This is the manual verification gate — v1 has no browser-automation tests.

## Setup

- `~/.config/control-panel/` exists and is writable.
- `~/.cache/control-panel/` exists.
- `~/.local/share/waybar-notes/` exists.
- `~/wallpapers/` has at least one .jpg/.png.

## Tests

1. **Launch via icon.** Click ⚙ in waybar → chromium app window opens with the
   sidebar visible. Server log shows `control-panel listening on …`.
2. **Launch via keybind.** Close the window, press `$mod+Shift+s` → same.
3. **Notes panel opens.** Sidebar shows 📝 Notes. Click it.
4. **Add a note.** Click `New`, type a title, type a body, wait 1 second →
   "Saved" toast appears, note shows in left list.
5. **Edit a note.** Click the note in the list, modify body, press Ctrl+S →
   "Saved" toast appears.
6. **Delete a note.** Click `Delete` → confirm prompt → note disappears.
7. **Waybar still rotates notes.** Wait ~30 s and check that the rotating
   waybar 📝 module shows a note title — proves the storage stayed compatible
   with the existing rofi flow.
8. **Wallpaper panel opens.** Sidebar shows 🖼️ Wallpaper.
9. **Apply a wallpaper.** Click a card → "Wallpaper set: …" toast → desktop
   background changes (swaybg gets reloaded).
10. **Theme panel opens.** Sidebar shows 🎨 Theme.
11. **Apply blue-cyan.** Click the blue-cyan swatch card → waybar, mako,
    rofi (next launch), and new foot windows pick up the new colors.
12. **Revert.** Click `Revert last apply` → colors go back to pink-green.
13. **Close window.** Server process exits cleanly (no zombie).

## If anything fails

Run `python -m pytest -v` from `config/control-panel/`. All backend tests
should pass — if they don't, fix there first. Frontend bugs require eyeballing
the browser devtools console.
