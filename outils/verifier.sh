#!/usr/bin/env bash
set -euo pipefail

RACINE="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/bin:$PATH"

cd "$RACINE"

echo "Validation Godot : import et analyse des scripts"
godot --headless --path "$RACINE" --editor --quit

echo "Smoke test : demarrage de la scene principale"
godot --headless --path "$RACINE" --quit-after 3

echo "Validation terminee"
