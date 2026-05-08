# Control Panel — Design Spec

**Date:** 2026-05-08
**Status:** Draft, pending implementation
**Owner:** areej

## Summary

A lightweight web-based control panel for tweaking system settings on this Sway/Wayland setup. Replaces and extends the rofi-driven settings flow (currently: notes only) with a modular browser UI that can grow over time. v1 ships three panels: notes, wallpaper, color theme.

Design priorities, in order: minimal install footprint, modular (new panels are one frontend file + one backend file), no build toolchain, no long-running processes by default.

## Goals

- Manage notes (view, edit, add, delete) from a real UI instead of cascading rofi prompts.
- Switch wallpapers from a thumbnail grid backed by `~/wallpapers/`.
- Switch system color theme from preset palettes; reload affected daemons in place.
- Stay extensible: future panels (display, audio, bluetooth, etc.) drop in without core changes.

## Non-goals

- Cross-machine settings sync.
- Authentication / multi-user (loopback only, single-user box).
- A native desktop app shell (chromium `--app=` window is enough for now; tauri/webview wrapping is a later option).
- Custom-palette editor in v1 (data model supports it; UI deferred to v2).

## Architecture

### Top-level layout

A new top-level directory in this repo, sibling to `waybar/`, `sway/`, etc.:

```
config/control-panel/
├── server.py              # Python stdlib http.server, no third-party deps
├── launch.sh              # on-demand: start server, open chromium, kill on exit
├── daemon.sh              # optional persistent mode (deferred to post-v1)
├── handlers/              # one .py per panel, auto-discovered at startup
│   ├── notes.py
│   ├── wallpaper.py
│   └── theme.py
├── web/
│   ├── index.html         # shell — sidebar nav + content slot
│   ├── app.js             # panel registry + router
│   ├── styles.css         # uses palette tokens (CSS custom properties)
│   └── panels/            # one .js per panel, auto-discovered via /api/_panels
│       ├── notes.js
│       ├── wallpaper.js
│       └── theme.js
├── themes/                # named preset palettes (JSON)
│   ├── pink-green.json
│   ├── blue-cyan.json
│   └── amber-violet.json
└── templates/             # per-app config templates with {{colors.*}} placeholders
    ├── rofi.theme.rasi.tmpl
    ├── waybar.style.css.tmpl
    ├── mako.config.tmpl
    └── foot.ini.tmpl
```

### Runtime flow

1. User clicks the ⚙️ icon in waybar (or hits Sway keybind `$mod+Shift+s`) → `launch.sh` runs.
2. `launch.sh` finds a free loopback port, exports it as `CONTROL_PANEL_PORT`, starts `server.py` bound to `127.0.0.1:$PORT`.
3. `launch.sh` execs `chromium --app=http://127.0.0.1:$PORT` (the `--app=` flag gives a chromeless window — feels app-like, no tabs/URL bar).
4. When chromium exits, `launch.sh` kills the server PID. Clean shutdown, no zombie.
5. `daemon.sh` (post-v1) skips chromium; sway autostart line keeps the server warm.

### Security model

- Server binds to `127.0.0.1` only — never `0.0.0.0`.
- No authentication. Anything on this machine that can reach loopback can already read these config files; adding auth is theatre.
- Server writes only inside: `~/.local/share/notes/`, `~/.config/control-panel/`, `~/.cache/control-panel/`, `~/.config/{rofi,waybar,mako,foot}/`, and `~/wallpapers/` (read-only).
- All path joins go through a `safe_join(base, user_input)` helper that rejects `..`, absolute paths, and symlinks pointing outside `base`.

## Modularity contract

The whole point: adding a new panel later (brightness, audio, bluetooth, kanji-mode, whatever) should be one frontend file + one backend file with zero core changes.

### Frontend panel module

Every panel is a single ES module that exports one default object:

```js
// web/panels/<id>.js
export default {
  id: "notes",                      // unique; used in URL hash and API namespace
  title: "Notes",                   // sidebar label
  icon: "📝",                       // emoji or short svg path
  order: 10,                        // sidebar sort order (lower = higher in list)
  mount(root, api) { ... },         // render into `root` (an empty <div>)
  unmount(root) { ... }             // cleanup (timers, listeners). May be a no-op.
};
```

The `api` argument is the only channel a panel uses to reach the backend or the host UI:

```js
api.get(path)                       // → fetch('/api/<panel-id>/' + path).json()
api.post(path, body)                // → fetch with JSON body, returns parsed JSON
api.notify(msg, kind)               // toast: kind ∈ {"info","success","error"}
api.confirm(msg)                    // returns Promise<bool>
```

`api` is constructed by `app.js` per-panel and rebinds the panel's id automatically — a panel cannot accidentally hit another panel's API namespace.

### Backend handler module

Symmetrical. Each panel has one Python module in `handlers/`:

```python
# handlers/notes.py     — panel id is the filename minus ".py"

def handle(method, subpath, body):
    """
    method:  "GET" or "POST"
    subpath: path after /api/<id>/, e.g. "list", "save", "delete/abc123"
    body:    parsed JSON dict, or None for GET / empty body
    returns: (status_int, json_serializable)
    raises:  HandlerError(status, msg) for clean 4xx
    """
    ...
```

`server.py` discovers handlers at startup by importing every non-underscore `.py` in `handlers/`. Panel id is the module's filename — no manual id constant, no chance of frontend/backend ids drifting apart since the directory layout enforces them. The frontend gets the panel list via `GET /api/_panels` (returns `[{id, title, icon, order}]` derived from each panel module's exported metadata) — but since the frontend `mount()` lives in JS, the *frontend* list is built by importing every `.js` in `web/panels/`. A small generated `panels/index.js` re-exports them all; this file is rebuilt on server startup so dropping a new `.js` file and reloading the page picks it up.

## Panels (v1)

### Notes

**Replaces** the existing rofi flow (`notes.sh`, `notes-list.sh`, `notes-add.sh`). Those scripts keep working — waybar's rotating-notes display still reads the same directory — but the panel becomes the primary UI for editing.

**Storage:** `~/.local/share/notes/`, one file per note, filename `<ISO-timestamp>-<slug>.txt`. (Implementation step: confirm existing notes directory and migrate if needed; note files are plain text either way.)

**UI:** two-pane. Left = list of notes, most recent first, showing title + relative mtime. Right = editor (`<textarea>` for v1; markdown preview tab is a stretch). Buttons: New, Save, Delete. Save fires on Ctrl+S, on textarea blur, and (debounced) 1 second after the user stops typing.

**API:**

| Method | Path                       | Body                       | Returns                        |
|--------|----------------------------|----------------------------|--------------------------------|
| GET    | /api/notes/list            | —                          | `[{id, title, mtime}]`         |
| GET    | /api/notes/get/<id>        | —                          | `{id, title, body, mtime}`     |
| POST   | /api/notes/save            | `{id?, title, body}`       | `{id}`                         |
| POST   | /api/notes/delete/<id>     | —                          | `{ok: true}`                   |

### Wallpaper

**Source:** `~/wallpapers/` by default (the directory `rofi/theme.rasi` already references). Configurable via UI; the chosen path is saved to `~/.config/control-panel/wallpaper.dir`.

**Apply:** writes `~/.config/control-panel/wallpaper.current` with the selected filename, then runs `swaymsg "exec swaybg -i <path> -m fill"` after killing any existing `swaybg`. The current sway start script will source `wallpaper.current` on next login so wallpaper survives reboots.

**Thumbnails:** server generates 200×120 thumbs lazily into `~/.cache/control-panel/thumbs/<sha1-of-fullpath>.jpg` using `convert` (ImageMagick) if available, or symlinks the original if not. Cache invalidated by source mtime.

**API:**

| Method | Path                       | Body                       | Returns                                  |
|--------|----------------------------|----------------------------|------------------------------------------|
| GET    | /api/wallpaper/list        | —                          | `[{name, thumb_url}]`                    |
| GET    | /api/wallpaper/current     | —                          | `{name}`                                 |
| POST   | /api/wallpaper/set         | `{name}`                   | `{ok: true}`                             |
| GET    | /api/wallpaper/dir         | —                          | `{path}`                                 |
| POST   | /api/wallpaper/dir         | `{path}`                   | `{ok: true}`                             |

### Theme

**Data model** — a palette is a flat JSON object with named color slots. v1 ships three:

```json
{
  "name": "pink-green",
  "label": "Pink & Green",
  "colors": {
    "bg":       "#1e1b2e",
    "bg_alt":   "#2d2b3d",
    "fg":       "#f8f8f2",
    "accent":   "#f48fb1",
    "accent_2": "#e91e8c",
    "ok":       "#a8d8a8",
    "muted":    "#888888"
  }
}
```

The active palette is mirrored at `~/.config/control-panel/theme.current.json`. v1 picks from `themes/` bundled with the repo; v2's custom-palette editor will save user palettes alongside, using the same loader and apply pipeline — no rework.

**Apply pipeline** — on `POST /api/theme/apply`:

1. Read selected palette from `themes/<name>.json`.
2. Back up current versions of the four target config files into `~/.config/control-panel/backup/<timestamp>/` (one-deep history; `revert` restores the latest backup).
3. For each template in `templates/`, read template, substitute `{{colors.bg}}`, `{{colors.fg}}`, etc., write to the real path.
4. Mirror palette to `~/.config/control-panel/theme.current.json`.
5. Reload daemons:
   - `swaymsg reload` — picks up wallpaper / sway-level styling.
   - `pkill -SIGUSR2 waybar` — waybar reloads its CSS.
   - `pkill -SIGUSR1 mako` — mako reloads config.
   - rofi has no daemon; next launch reads the new theme.
   - foot — already-open windows keep old colors (foot has no live-reload signal); new windows get new colors. Document this; don't try to work around.

**Templatization step (one-time, prerequisite for v1):** the current `rofi/theme.rasi` and `waybar/style.css` have palette colors inlined. Before the theme panel can ship, we extract those colors into `pink-green.json` and replace the inlined hex with `{{colors.*}}` placeholders, producing the `.tmpl` files. The first `apply` of `pink-green` must produce byte-equivalent output to the current files — this is the safety check that proves the templatization didn't lose information.

**API:**

| Method | Path                       | Body                       | Returns                                  |
|--------|----------------------------|----------------------------|------------------------------------------|
| GET    | /api/theme/list            | —                          | `[{name, label, colors}]`                |
| GET    | /api/theme/current         | —                          | `{name, colors}`                         |
| POST   | /api/theme/apply           | `{name}`                   | `{ok: true}`                             |
| POST   | /api/theme/revert          | —                          | `{ok: true, name}`                       |

## Integration with existing repo

- New waybar custom module `custom/control-panel` — single ⚙️ icon, on-click runs `launch.sh`. Position: right side, immediately left of `notes`.
- New Sway keybind `$mod+Shift+s` → `exec ~/.config/control-panel/launch.sh`.
- `setup.sh` — add a step to `chmod +x` the two scripts and create `~/.config/control-panel/` and `~/.cache/control-panel/`.
- `install.sh` — no new dependencies for v1 (Python stdlib + chromium are already there). ImageMagick (`convert`) is opt-in for thumbs; falls back gracefully.

## Testing

- **Backend handlers** are pure: `handle(method, subpath, body) → (status, body)`. One pytest file per handler tests them directly, no HTTP. Filesystem effects use `tmp_path`.
- **Server core** — one integration test boots the server on an ephemeral port, hits `/api/_panels`, hits one route per panel, asserts shape. Confirms wiring and auto-discovery.
- **Frontend panels** — mount each panel's module against a fake `api` object that returns canned data; assert DOM shape after `mount`. No browser automation in v1.
- **Templatization safety** — a test renders `pink-green.json` through every template and `diff`s against the pre-templatization snapshots of the live config files. Must be byte-equivalent.
- **Manual smoke checklist** lives in `config/control-panel/SMOKE.md` and is run on Areej's machine after each significant change: launch, switch theme, revert, change wallpaper, add note, edit note, delete note, close.

## v1 scope

Ships in v1:

1. `server.py` with handler auto-discovery and `safe_join`.
2. `launch.sh` (on-demand) + waybar ⚙️ button + Sway keybind.
3. Notes panel (replaces rofi as primary; rofi flow stays as fallback).
4. Wallpaper panel.
5. Theme panel with three preset palettes (`pink-green`, `blue-cyan`, `amber-violet`).
6. Templatized `rofi.theme.rasi`, `waybar.style.css`, `mako.config`, `foot.ini`; pink-green output byte-equivalent to current files.
7. Tests as described above; smoke checklist passes.

Deferred (post-v1):

- `daemon.sh` mode + sway autostart entry.
- Custom-palette editor UI (data model already supports it).
- Live theme preview on swatch hover.
- Additional panels (brightness, audio, bluetooth, etc.).
- Playwright / browser automation tests.
- Native window wrapping (tauri/webview).

## Risks and mitigations

| Risk                                                         | Mitigation                                                                          |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------|
| Templatization silently drops a CSS rule from `style.css`.   | Byte-equivalence test in CI; manual diff before first commit.                       |
| `swaybg` reload races with sway reload during theme apply.   | Apply order: write files, then `swaymsg reload`, then `pkill -SIGUSR2 waybar`.      |
| Port collision if another local server uses the same port.   | `launch.sh` picks a free ephemeral port via Python `socket.bind((,0))`.             |
| Panel writes outside its sandbox.                            | All writes go through `safe_join`; review per-panel during implementation.          |
| Chromium not installed.                                      | `launch.sh` falls back to `xdg-open` if `chromium` not on PATH; logs a warning.     |
| Foot windows keep old palette after theme change.            | Document; do not paper over.                                                        |
