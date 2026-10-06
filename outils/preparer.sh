#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.6.1"
VENDORS_VERSION="5.1.0-stable"
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
TRAVAIL="${RUNNER_TEMP:-/tmp}/godot_travail"
mkdir -p "$TRAVAIL" "$HOME/bin"
cd "$TRAVAIL"

echo "Telechargement de Godot ${GODOT_VERSION}"
curl -fsSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
unzip -q -o godot.zip
mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$HOME/bin/godot"
chmod +x "$HOME/bin/godot"

echo "Telechargement des modeles d'export"
curl -fsSL -o modeles.tpz "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
unzip -q -o modeles.tpz
DEST="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
mkdir -p "$DEST"
cp -r templates/. "$DEST/"

echo "Modele de compilation Android"
mkdir -p "$RACINE/android/build"
unzip -q -o templates/android_source.zip -d "$RACINE/android/build"
touch "$RACINE/android/build/.gdignore"
printf '%s' "${GODOT_VERSION}.stable" > "$RACINE/android/.build_version"

echo "Plugin Quest (godot_openxr_vendors ${VENDORS_VERSION})"
curl -fsSL -o vendors.zip "https://github.com/GodotVR/godot_openxr_vendors/releases/download/${VENDORS_VERSION}/godotopenxrvendorsaddon.zip"
unzip -q -o vendors.zip -d vendors
mkdir -p "$RACINE/addons"
cp -r vendors/asset/addons/godotopenxrvendors "$RACINE/addons/"

echo "Preparation terminee"
