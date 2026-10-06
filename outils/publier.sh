#!/usr/bin/env bash
set -euo pipefail

ETIQUETTE="derniere-version"
DEPOT="${GITHUB_REPOSITORY}"

if ! gh release view "$ETIQUETTE" -R "$DEPOT" > /dev/null 2>&1; then
  gh release create "$ETIQUETTE" -R "$DEPOT" --title "Derniere version" --notes "APK Mandala VR pour Quest 3"
fi
gh release upload "$ETIQUETTE" build/mandala_vr.apk -R "$DEPOT" --clobber
