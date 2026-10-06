#!/usr/bin/env bash
set -euo pipefail

RACINE="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/bin:$PATH"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
JAVA="${JAVA_HOME:-/usr/lib/jvm/temurin-17-jdk-amd64}"

echo "Composants Android"
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKM" --licenses > /dev/null || true
"$SDKM" "platform-tools" "build-tools;35.0.1" "platforms;android-35" "ndk;28.1.13356709" > /dev/null

echo "Reglages de l'editeur"
mkdir -p "$HOME/.config/godot"
for f in editor_settings-4.6.tres editor_settings-4.tres; do
cat > "$HOME/.config/godot/$f" <<REGLAGES
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA"
REGLAGES
done

echo "Cle de signature"
CLE="$HOME/mandala.keystore"
rm -f "$CLE"
keytool -genkeypair -keystore "$CLE" -alias mandala -keyalg RSA -keysize 2048 -validity 10000 -storepass motdepasse -keypass motdepasse -dname "CN=Mandala VR,O=Mandala,C=FR" > /dev/null
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$CLE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="mandala"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="motdepasse"

cd "$RACINE"
mkdir -p build

echo "Import du projet"
godot --headless --path "$RACINE" --import || true
godot --headless --path "$RACINE" --import || true

echo "Export"
godot --headless --path "$RACINE" --export-release Quest "$RACINE/build/mandala_vr.apk"

test -s "$RACINE/build/mandala_vr.apk"
ls -la "$RACINE/build"
