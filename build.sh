#!/bin/bash
# Copies the addon folders from this project into the game's AddOns folder, overwriting what's there.
#   ./build.sh           copy new and changed files
#   ./build.sh --delete  also remove files from the game copy that no longer exist here
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="/Applications/World of Warcraft/_forever_/Interface/AddOns"
ADDONS=(WowGamePadTweaks WowGamePadTweaks_Keyboard WowGamePadTweaks_Rings WowGamePadTweaks_Touch)

DELETE=()
if [[ "${1:-}" == "--delete" ]]; then DELETE=(--delete); fi

if [[ ! -d "$DEST" ]]; then
	echo "AddOns folder not found: $DEST" >&2
	exit 1
fi

for addon in "${ADDONS[@]}"; do
	if [[ ! -d "$SRC/$addon" ]]; then
		echo "skip $addon (not in project)"
		continue
	fi
	rsync -a ${DELETE[@]+"${DELETE[@]}"} --exclude ".git" --exclude ".DS_Store" "$SRC/$addon/" "$DEST/$addon/"
	echo "updated $addon"
done

echo "Done. Type /reload in game to load the changes."
