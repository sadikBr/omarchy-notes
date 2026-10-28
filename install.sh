#!/usr/bin/env bash
# Install (or update) the bsadik.notes Omarchy shell plugin from this repo.
#
#   ./install.sh             copy plugin, add bar widget after the pomodoro timer, add keybinding
#   ./install.sh --uninstall remove plugin, bar widget and keybinding
#
# Safe to re-run: every step checks before changing anything.

set -euo pipefail

ID="bsadik.notes"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/$ID"
DEST="$HOME/.config/omarchy/plugins/$ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
BINDINGS="$HOME/.config/hypr/bindings.lua"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

BIND_START="-- >>> $ID >>>"
BIND_END="-- <<< $ID <<<"

say() { printf '\033[1;34m::\033[0m %s\n' "$*"; }

edit_shell_json() {
  local filter="$1"
  jq --arg id "$ID" "$filter" "$SHELL_JSON" >"$SHELL_JSON.tmp"
  mv "$SHELL_JSON.tmp" "$SHELL_JSON"
}

remove_binding() {
  [[ -f $BINDINGS ]] || return 0
  sed -i "/^$BIND_START\$/,/^$BIND_END\$/d" "$BINDINGS"
}

reload_hyprland() {
  if command -v hyprctl >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload >/dev/null
    local errors
    errors=$(hyprctl configerrors)
    [[ -z $errors || $errors == *"no errors"* ]] || echo "$errors" >&2
  fi
}

uninstall() {
  say "Removing $DEST"
  rm -rf "$DEST"
  if [[ -f $SHELL_JSON ]]; then
    say "Removing bar widget"
    edit_shell_json '
      (.bar.layout // {}) |= with_entries(.value |= map(select(.id != $id)))
      | (.plugins // []) |= map(select(.id != $id))'
  fi
  say "Removing keybinding"
  remove_binding
  reload_hyprland
  say "Uninstalled. Your notes are kept in ~/Documents/notes."
}

install() {
  [[ -f $SRC/manifest.json ]] || { echo "missing $SRC/manifest.json" >&2; exit 1; }
  for cmd in jq rsync; do
    command -v "$cmd" >/dev/null || { echo "missing dependency: $cmd" >&2; exit 1; }
  done

  say "Copying plugin to $DEST"
  mkdir -p "$DEST"
  rsync -a --delete "$SRC/" "$DEST/"
  omarchy plugin validate "$DEST" >/dev/null

  [[ -f $SHELL_JSON ]] || cp "$OMARCHY_PATH/config/omarchy/shell.json" "$SHELL_JSON"

  # A plugin that is also a bar widget is enabled by its bar entry, so it must
  # not also sit in plugins[]. Place it in the center, right after the pomodoro
  # timer (or the clock when the timer isn't there); otherwise append it.
  say "Adding bar widget to the center section"
  edit_shell_json '
    (.plugins // []) |= map(select(.id != $id))
    | if ([.bar.layout[]?[]?.id] | index($id)) then .
      else .bar.layout.center = (
        (.bar.layout.center // []) as $center
        | ($center | map(.id)) as $ids
        | ($ids | index("bsadik.pomodoro") // ($ids | index("omarchy.clock"))) as $after
        | if $after == null then $center + [{id: $id}]
          else $center[:$after + 1] + [{id: $id}] + $center[$after + 1:] end)
      end'

  say "Binding SUPER+ALT+N (popup)"
  remove_binding
  cat >>"$BINDINGS" <<BIND
$BIND_START
-- Notes plugin.
o.bind("SUPER + ALT + N", "Notes", "omarchy-shell shell toggle $ID")
$BIND_END
BIND
  reload_hyprland

  # The shell caches plugin QML that is already loaded, so code changes only
  # take effect after a restart.
  if command -v omarchy-shell >/dev/null && omarchy-shell shell ping 2>/dev/null | grep -q ok; then
    say "Restarting the Omarchy shell to load the new code"
    omarchy restart shell >/dev/null 2>&1 || say "Restart failed; run: omarchy restart shell"
  fi

  say "Done. Click the checklist icon in the bar, or press SUPER+ALT+N."
}

case "${1:-}" in
  --uninstall) uninstall ;;
  "") install ;;
  *) echo "usage: $0 [--uninstall]" >&2; exit 2 ;;
esac
