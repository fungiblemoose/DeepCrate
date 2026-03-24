# DeepCrateMac

DeepCrateMac is the primary macOS app for DeepCrate.

It is now a Swift-native macOS app at runtime. Scan/import analysis, reanalysis, set planning, persistence, gap analysis, Spotify discovery, and export all run inside the app.

## Current Status

- Native SwiftUI app with pages: Library, Build Set, Sets, Gaps, Discover, Export
- Local audio preview in Library and Sets
- Manual metadata overrides + review workflow in Library
- Planning modes:
  - Local Apple Foundation Models planner
  - Local model server planner via chat-completions HTTP
- SQLite reads/writes for tracks, sets, set tracks, and gaps in Swift
- Spotify discovery in Swift using the Spotify Web API
- Gap analysis + severity labeling in Swift
- M3U/Rekordbox export in Swift

## Architecture

Swift-native (`DeepCrateMac/Sources/DeepCrateMac/`):
- App shell/navigation/UI
- Library scan/import and audio reanalysis
- Native audio analysis pipeline (BPM/key/energy/preview cue)
- Planner orchestration and model routing
- Local model server planner client
- Native Spotify discovery client
- Local SQLite service (`LocalDatabase`)
- Transition scoring and gap analysis
- Export writers (M3U and Rekordbox XML)
- Audio preview playback

Legacy Python repo components:
- Compatibility CLI / GUI code
- Older analysis / planning modules kept for testing or comparison

## Requirements

- macOS 14+
- Xcode Command Line Tools
- Swift toolchain supporting this package (`swift-tools-version: 6.2`)

## Setup

From repo root:

```bash
cd /Users/jacksoneaker/Projects/DeepCrate
cp .env.example .env
```

Notes:
- `.env` can seed first-run planner/discovery/database settings.
- Values saved in-app via `Settings` take precedence over `.env`.
- `LOCAL_MODEL_ENDPOINT` should point at a local chat-completions server if you want stronger local planning than the built-in Apple model.

Optional if you want to run legacy Python tooling or Python tests:

```bash
python3 -m venv .venv
./.venv/bin/pip install -e .
```

## Run

Run from the `DeepCrateMac` directory during development so relative project paths resolve predictably:

```bash
cd /Users/jacksoneaker/Projects/DeepCrate/DeepCrateMac
swift run
```

## Build

```bash
cd /Users/jacksoneaker/Projects/DeepCrate/DeepCrateMac
swift build
```

## Packaging (GitHub Download + Drag to Applications)

From repo root:

```bash
./scripts/package-macos-app.sh
```

This builds:

- `dist/DeepCrate-<version>-macOS-<arch>.zip`
- `dist/DeepCrate-<version>-macOS-<arch>.dmg` (includes an `Applications` shortcut for drag-install)

Optional signing/notarization environment variables:

- `DEEPCRATE_CODESIGN_IDENTITY`
- `DEEPCRATE_NOTARY_APPLE_ID`
- `DEEPCRATE_NOTARY_APP_PASSWORD`
- `DEEPCRATE_NOTARY_TEAM_ID`

GitHub Actions workflow:

- `.github/workflows/release-macos.yml` builds the macOS bundle on tag pushes (`v*`) and uploads the DMG/ZIP to the release.
- The packaged app does not embed a Python runtime anymore.

## Licensing

- Project license: MIT (`../LICENSE`)
- Third-party notices: `../THIRD_PARTY_NOTICES.md`
