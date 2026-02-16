# DeepCrateMac

Native macOS SwiftUI rewrite scaffold for DeepCrate.

## Status

This is a production-oriented starting point with:
- Native macOS window + sidebar navigation
- Preferences window (`Settings`) for OpenAI/Spotify/database config
- Planner mode toggle (`Local Apple Model` vs `OpenAI`)
- Core feature screens: Library, Plan, Sets, Gaps, Discover, Export

The Swift UI is now wired to your existing Python DeepCrate backend through `deepcrate/mac_bridge.py` for:
- scan
- track search
- set planning (OpenAI mode)
- set listing + set tracks
- gap analysis
- discover suggestions
- export

`Local Apple Model` mode in Plan now uses Apple's Foundation Models framework to choose track IDs, then persists the set to your SQLite DB through the bridge.

## Run

```bash
cd /Users/jacksoneaker/Projects/DeepCrate
./.venv/bin/pip install -e .
cd DeepCrateMac
swift run
```

## Build

```bash
cd DeepCrateMac
swift build
```

## Next wiring steps

1. Implement SQLite read/write service (reuse existing schema from Python app).
2. Replace scan stubs with native scanner or Python bridge process.
3. Replace planner stubs:
   - `LocalPlanner`: Apple Foundation Models framework
   - `OpenAIPlanner`: URLSession-based OpenAI client
4. Implement real export writers (`.m3u`, Rekordbox XML).

## Distribution (GitHub, no App Store required)

You can distribute outside the App Store:
1. Build an app bundle with Xcode.
2. Codesign with Apple Developer ID.
3. Notarize with Apple.
4. Ship a `.dmg` on GitHub Releases.

Users drag `DeepCrate.app` into `/Applications`.
