# Releasing to Steam

Builds are exported by `tools/export.sh` into `build/windows/` and `build/linux/`. `tools/steam_upload.sh` exports and uploads them.

## What the owner must fill in
Nothing secret lives in the repo. Set these in your shell (or CI secrets):

| Variable | Meaning |
|---|---|
| `STEAM_APP_ID` | Steamworks app id of the game |
| `STEAM_DEPOT_WINDOWS` | Depot id for the Windows build |
| `STEAM_DEPOT_LINUX` | Depot id for the Linux build |
| `STEAM_USER` | Steam account that has "Edit App Metadata" and "Publish App Changes" rights |

The files in `tools/steam/` are templates: `${STEAM_APP_ID}` and friends are replaced by the script into a temp folder at upload time. The script refuses to run when a variable is unset or still a placeholder `0`.

## Commands
```bash
export STEAM_APP_ID=... STEAM_DEPOT_WINDOWS=... STEAM_DEPOT_LINUX=... STEAM_USER=...
tools/steam_upload.sh              # export, then upload
STEAM_SKIP_EXPORT=1 tools/steam_upload.sh   # upload the existing build/
```
Install `steamcmd` first. The first login asks for your password and a Steam Guard code; steamcmd caches the session afterwards, so run `steamcmd +login $STEAM_USER +quit` once by hand. The upload lands on no live branch: set the build live in the Steamworks partner site.
