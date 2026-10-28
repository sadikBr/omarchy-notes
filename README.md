# Omarchy Notes

A todo list and scratchpad for [Omarchy](https://omarchy.org), built as an Omarchy shell (Quickshell) plugin. It sits in the bar's center section next to the pomodoro timer and shows the task you're working on. Both lists are plain markdown files, so you can also edit them in any editor.

## Bar widget

The widget shows a checklist icon and the **current task**, which is the first open task in the list. Long tasks are cut short with `…`. When nothing is open, the icon is dimmed.

| Mouse | Action |
|---|---|
| Left click | Open the popup |
| Right click | Mark the current task done |
| Middle click | Open `todo.md` in your editor |

## Popup

**Todo tab**

- The add field has focus when the popup opens: press SUPER+ALT+N, type the task, press Enter
- Click a task to tick or untick it. Ticked tasks move below the open ones
- Hover a task for **Make current** (moves it to the top) and **Delete**
- The current task is highlighted and marked with a target icon
- **Clear done** removes all ticked tasks

**Scratch tab**: free text, saved as you type.

The button in the top-right corner opens the file for the current tab in your editor (`omarchy launch editor`).

## Keys

| Key | Action |
|---|---|
| SUPER+ALT+N | Toggle the popup |
| Enter | Add the task (Todo tab) |
| Tab / Shift+Tab | Switch between Todo and Scratch |
| Esc | Close the popup |

## Files

| File | Contents |
|---|---|
| `~/Documents/notes/todo.md` | The todo list as a markdown checklist (`- [ ] task` / `- [x] task`) |
| `~/Documents/notes/scratch.md` | The scratchpad |

Both files are watched, so changes made in an editor show up in the popup straight away. The popup only rewrites checklist lines. Headings, blank lines and other notes you add to `todo.md` by hand are kept where they are.

## Command line

The plugin registers a `bsadik.notes` IPC target:

```bash
omarchy-shell bsadik.notes add "Review PR"   # add a task
omarchy-shell bsadik.notes current           # print the current task
omarchy-shell bsadik.notes done              # tick the current task
omarchy-shell bsadik.notes list              # print every task
omarchy-shell bsadik.notes status            # JSON: open, done, current, file
omarchy-shell bsadik.notes panel             # toggle the popup
```

## Settings

These go on the widget's entry in `~/.config/omarchy/shell.json`:

| Key | Default | Meaning |
|---|---|---|
| `showTask` | `true` | Show the current task in the bar. Set it to `false` to show only the open count |
| `maxTaskChars` | `28` | Longest task text shown in the bar |

```json
{ "id": "bsadik.notes", "showTask": false }
```

## Install

```bash
cd ~/Work/omarchy-notes-plugin
./install.sh
```

`install.sh` is safe to re-run. It:

1. copies `bsadik.notes/` to `~/.config/omarchy/plugins/bsadik.notes/`
2. adds the widget to the bar's center section, right after `bsadik.pomodoro` (or after the clock if the pomodoro timer isn't installed)
3. adds a marked SUPER+ALT+N block to `~/.config/hypr/bindings.lua` and reloads Hyprland
4. restarts the Omarchy shell, which caches plugin code that is already loaded

After editing anything in this repo, run `./install.sh` again to apply it. Omarchy rejects symlinked plugin folders, so the plugin is copied rather than linked.

To remove it: `./install.sh --uninstall`. Your notes stay in `~/Documents/notes`.

## How it works

| File | Purpose |
|---|---|
| `bsadik.notes/manifest.json` | Plugin manifest (service and bar widget, settings schema) |
| `bsadik.notes/Service.qml` | Reads, watches and writes the two files; task operations; IPC |
| `bsadik.notes/BarWidget.qml` | Bar icon, current task, and popup host |
| `bsadik.notes/NotesPanel.qml` | Popup contents: tabs, add field, checklist, scratchpad |
| `bsadik.notes/Notes.js` | Icons and the markdown checklist parser/writer |

The popup is a `KeyboardPanel` rather than a `PopupCard`. A popup window only gets keyboard input after the pointer has been inside it, but the layer-shell panel takes focus as soon as it opens, so the hotkey can go straight to typing.

## Requirements

- Omarchy with the Quickshell-based `omarchy-shell` and Lua Hyprland config
- `JetBrainsMono Nerd Font` (Omarchy default) for the icons
- `jq` and `rsync` (for `install.sh`)
