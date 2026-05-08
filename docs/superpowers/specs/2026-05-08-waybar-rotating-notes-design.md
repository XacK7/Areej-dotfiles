# Waybar Rotating Notes — Design

**Date:** 2026-05-08
**Status:** Approved, pending implementation

## Goal

Add a notes module to the right side of waybar that rotates through saved notes (showing the title on the bar) and exposes view/add/edit/delete actions through rofi.

## Storage

- **Directory:** `~/.local/share/waybar-notes/`
- **One note = one file:** `YYYY-MM-DD-HHMMSS.txt`
  - Timestamp filename guarantees uniqueness without sanitizing user input.
  - Alphabetical sort = chronological order.
- **File format:**
  - First line = title (shown on waybar)
  - Remaining lines = body (shown in tooltip and View dialog)
- **Empty body** is valid — new notes from waybar start title-only; body added later via Edit.

## Waybar module: `custom/notes`

### Placement

Rightmost group of `modules-right`, immediately before `custom/weather`:

```json
"modules-right": ["custom/notes", "custom/weather", "sway/language", "pulseaudio", "tray"]
```

### Module config

```json
"custom/notes": {
    "exec":         "~/.config/waybar/notes.sh",
    "return-type":  "json",
    "interval":     30,
    "on-click":     "~/.config/waybar/notes-list.sh",
    "on-click-right": "~/.config/waybar/notes-add.sh"
}
```

### Display

- Format: `📝 <title>` where title is the first line of the currently-rotated note.
- Truncation: titles longer than 30 chars truncated with `…`.
- Tooltip: full body of the current note (or "No body" placeholder if empty body).
- Empty state (no note files exist): displays `📝 (no notes)`. Right-click still works to add the first note; left-click does nothing useful but should not error.

### Rotation

- Sequential cycle through notes sorted alphabetically (= chronological).
- Interval: 30 seconds (driven by waybar's `interval`).
- State: `~/.cache/waybar-notes-index` stores current index. Script reads, displays, advances, writes back.
- Index wraps to 0 when it exceeds note count.
- Adding/deleting notes between ticks is tolerated: the script clamps the stored index against the current note count before using it.

## Scripts

All scripts live in `config/waybar/` (deployed as symlinks to `~/.config/waybar/`).
All scripts must be marked executable in git via `git update-index --chmod=+x` due to the Windows git chmod limitation noted in prior memory.

### `notes.sh` (waybar exec)

1. Ensure note directory exists (`mkdir -p`).
2. List `*.txt` files sorted alphabetically.
3. If empty: emit `{"text": "📝 (no notes)", "tooltip": "Right-click to add a note"}` and exit 0.
4. Read index from `~/.cache/waybar-notes-index` (default 0); clamp to `[0, count-1]`.
5. Read first line of selected file → title; rest of file → body.
6. Truncate title to 30 chars + `…` if longer.
7. Emit JSON: `{"text": "📝 <title>", "tooltip": "<body or 'No body'>"}`.
8. Write `(index + 1) % count` back to the cache file.

JSON values must be properly escaped for waybar (newlines in tooltip → `\n` literal; double-quotes escaped).

### `notes-list.sh` (left-click handler)

1. List notes; if none, exit silently.
2. Build a rofi menu where each entry is the title of a note, but the script remembers which file each title belongs to (e.g. by indexing the sorted file list and using rofi's selection index).
3. User selects a note → run a second rofi menu with three entries: `View`, `Edit`, `Delete`.
4. Dispatch:
   - **View:** show full body in `rofi -e` (message dialog), or in a `rofi -dmenu` with the body content split by lines.
   - **Edit:** launch `foot -e ${EDITOR:-nvim} <file>` so the editor opens in a terminal window.
   - **Delete:** show a `rofi -dmenu` with `Yes` / `No` confirmation; on `Yes`, `rm` the file.

Edge case: if a title is empty (file starts with blank line), display `(untitled)` for that entry.

### `notes-add.sh` (right-click handler)

1. Ensure note directory exists.
2. Prompt with `rofi -dmenu -p "New note"`.
3. If user cancels (empty exit), do nothing.
4. Generate filename `$(date +%Y-%m-%d-%H%M%S).txt`.
5. Write the input as the first line of the file. No body.

## Sway integration

No sway config changes required — the module is owned by waybar, and clicks are handled by the module's own scripts. Existing sway reload via `update.sh` on the remote will pick up waybar changes.

## CSS

Add a rule to `config/waybar/style.css` styling `#custom-notes` consistently with `#custom-weather` (same padding, same color band). Match the existing visual pattern; do not introduce a new color unless the user requests one.

## Install / deploy changes

- `setup.sh` (or whichever script handles first-run setup) gets `mkdir -p ~/.local/share/waybar-notes` appended so the directory exists on fresh deploy. The waybar script also creates it defensively.
- No new packages required — `rofi`, `foot`, and an `$EDITOR` are already present per prior phases.

## Testing checklist

- [ ] With zero notes: bar shows `📝 (no notes)`; right-click adds a note; bar updates within 30s.
- [ ] With one note: bar shows that note's title; rotation is a no-op.
- [ ] With multiple notes: titles cycle every 30s in alphabetical (= chronological) order.
- [ ] Long title is truncated with `…`; tooltip shows full body.
- [ ] Left-click → list → View shows body.
- [ ] Left-click → list → Edit opens `foot` with editor; saving updates the file; bar reflects change on next tick.
- [ ] Left-click → list → Delete with `Yes` removes the file; bar reflects removal on next tick.
- [ ] Deleting the currently-displayed note does not break the rotation index.
- [ ] Right-click → add note with empty input is a no-op (no zero-byte files).
- [ ] All three scripts have executable bits in git index (`ls-files --stage` shows `100755`).

## Out of scope

- Note search.
- Note priorities, tags, or categories.
- Sync across machines (the deploy pipeline copies config, not user data; notes live in `~/.local/share`).
- Markdown rendering or rich text.
- Reminders / scheduled notes.
