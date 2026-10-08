#!/usr/bin/env bash
# Builds release exports and uploads them to Steam with steamcmd. See docs/RELEASE.md.
# Needs STEAM_APP_ID, STEAM_DEPOT_WINDOWS, STEAM_DEPOT_LINUX and STEAM_USER in the environment.
# Set STEAM_SKIP_EXPORT=1 to upload the existing build/ folder. No secrets are stored in the repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
missing=()
for var in STEAM_APP_ID STEAM_DEPOT_WINDOWS STEAM_DEPOT_LINUX STEAM_USER; do
  if [[ -z "${!var:-}" ]]; then missing+=("$var"); fi
done
if (( ${#missing[@]} > 0 )); then
  echo "Refusing to upload: set ${missing[*]} (see docs/RELEASE.md)." >&2
  exit 1
fi
for var in STEAM_APP_ID STEAM_DEPOT_WINDOWS STEAM_DEPOT_LINUX; do
  if [[ ! "${!var}" =~ ^[0-9]+$ || "${!var}" =~ ^0+$ ]]; then
    echo "Refusing to upload: $var must be a real numeric id, got '${!var}'." >&2
    exit 1
  fi
done
command -v steamcmd >/dev/null || { echo "steamcmd not found on PATH." >&2; exit 1; }

if [[ "${STEAM_SKIP_EXPORT:-}" != "1" ]]; then
  "$ROOT/tools/export.sh"
fi

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
for f in "$ROOT"/tools/steam/*.vdf; do
  sed -e "s#\${STEAM_APP_ID}#$STEAM_APP_ID#g" \
      -e "s#\${STEAM_DEPOT_WINDOWS}#$STEAM_DEPOT_WINDOWS#g" \
      -e "s#\${STEAM_DEPOT_LINUX}#$STEAM_DEPOT_LINUX#g" \
      -e "s#\${ROOT}#$ROOT#g" "$f" > "$out/$(basename "$f")"
done
steamcmd +login "$STEAM_USER" +run_app_build "$out/app_build.vdf" +quit
