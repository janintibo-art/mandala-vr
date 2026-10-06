#!/usr/bin/env bash
set -euo pipefail

RACINE="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/bin:$PATH"
JOURNAL="$(mktemp)"

cd "$RACINE"

echo "Validation Godot : import et analyse des scripts"
godot --headless --path "$RACINE" --editor --quit 2>&1 | tee "$JOURNAL"

echo "Smoke test : demarrage de la scene principale (300 images)"
godot --headless --path "$RACINE" --quit-after 300 2>&1 | tee -a "$JOURNAL"

echo "Recherche d'erreurs de script"
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script|Invalid call|Invalid access|Invalid get index|Invalid set index" "$JOURNAL"; then
	echo "ECHEC : des scripts contiennent des erreurs (voir les lignes ci-dessus)"
	exit 1
fi

echo "Validation terminee"
