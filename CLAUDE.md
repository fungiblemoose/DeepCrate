# DeepCrate — Agent Reference

## What This Project Is

DeepCrate is a CLI-only Python tool for planning DJ sets. It analyzes local audio files (BPM, key, energy), uses OpenAI to plan sets from natural language descriptions, scores transitions using the Camelot harmonic mixing system, and exports playlists to M3U or Rekordbox XML.

## Tech Stack

- Python 3.12+, installed as editable package via `pip install -e .`
- CLI: `typer` with `rich` for output formatting
- Database: SQLite (sync, via `sqlite3` stdlib — not aiosqlite despite it being listed as a dep)
- Audio analysis: `librosa` (BPM, key via chromagram + Krumhansl-Kessler profiles, energy via RMS + spectral centroid)
- Metadata: `mutagen` for ID3 tags
- AI: `openai` SDK, default model `gpt-4o-mini`
- Discovery: `spotipy` for Spotify API
- Config: `pydantic-settings` loading from `.env`

## Project Layout

```
deepcrate/
├── cli.py              # All Typer commands. Entry point is `app`.
├── config.py           # Settings class, loads .env
├── db.py               # SQLite schema + all CRUD functions (sync, not async)
├── models.py           # Pydantic models: Track, SetPlan, SetTrack, Gap, TransitionInfo
├── analysis/
│   ├── scanner.py      # find_audio_files(directory) → list[Path]
│   ├── analyzer.py     # analyze_track(path) → Track, also file_hash(), detect_bpm/key/energy
│   └── camelot.py      # Camelot wheel: key mapping, compatible_keys(), key_compatibility_score()
├── planning/
│   ├── planner.py      # plan_set() — sends library to OpenAI, parses response, saves set
│   ├── prompts.py      # SYSTEM_PROMPT, build_library_context(), build_plan_prompt()
│   ├── scoring.py      # transition_score(), bpm/key/energy sub-scores, describe_transition()
│   └── gaps.py         # analyze_gaps() — finds weak transitions, suggests bridge tracks
├── discovery/
│   └── spotify.py      # search_tracks() via Spotify API with auto-doubled BPM for DnB
└── export/
    ├── m3u.py          # export_m3u(set_name) → file path
    └── rekordbox.py    # export_rekordbox(set_name) → file path
```

## Database Schema

SQLite at `data/deepcrate.sqlite`. Four tables:

- **tracks** — `id, file_path (UNIQUE), file_hash, title, artist, bpm, musical_key, energy_level, duration`
- **sets** — `id, name (UNIQUE), description, target_duration`
- **set_tracks** — `set_id, track_id, position, transition_score` (PK: set_id + position)
- **gaps** — `id, set_id, position, suggested_bpm, suggested_key, suggested_energy, suggested_vibe`

All DB access goes through `db.py` functions. Schema auto-creates on first connection via `_ensure_db()`.

## CLI Commands

| Command | What it does |
|---------|-------------|
| `deepcrate scan <dir>` | Analyze audio files, store in DB. Skips unchanged files (by hash). |
| `deepcrate stats` | Library overview: count, BPM range, top keys, total duration. |
| `deepcrate search` | Filter library by `--bpm`, `--key`, `--energy`, `-q` text search. |
| `deepcrate plan <description> --name <name> --duration <min>` | AI-powered set planning via OpenAI. |
| `deepcrate show <name>` | Display set tracklist with transition scores. |
| `deepcrate gaps <name>` | Find weak transitions, store gap suggestions. |
| `deepcrate discover --name <name> --gap <n>` | Search Spotify for tracks to fill a gap. |
| `deepcrate export <name> --format m3u\|rekordbox` | Export playlist file. |

## Key Design Decisions

- **Sync SQLite, not async.** The `aiosqlite` dep is vestigial. All DB calls in `db.py` use `sqlite3` directly. Each function opens/closes its own connection. This is fine for a CLI tool.
- **File hash for cache invalidation.** `file_hash()` hashes the first 1MB of the file (MD5). If the hash matches what's in the DB, the track is skipped during scan.
- **Pre-filtering for LLM context.** If the library has 200+ tracks, `planner.py` filters by inferred BPM range before sending to OpenAI. This keeps the prompt under token limits.
- **Transition scoring weights.** `scoring.py` uses 40% key + 35% BPM + 25% energy. Key is weighted highest because harmonic clashes are the most noticeable.
- **Half-tempo detection.** Both `scoring.py` and `spotify.py` handle the common issue of BPM being reported at half tempo (87 instead of 174 for DnB).

## Running Tests

```bash
source .venv/bin/activate
python -m pytest tests/ -v
```

21 tests covering:
- `test_camelot.py` — Key mapping, Camelot parsing, compatibility, wheel wrapping at 12→1
- `test_scoring.py` — BPM/energy/transition scoring, half-tempo, direction preference
- `test_analyzer.py` — File hashing, key detection output format, energy range validation

Tests don't require audio files or API keys. Analyzer tests use synthetic numpy signals.

## Environment Variables

Set in `.env` at project root:

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `OPENAI_API_KEY` | For `plan` command | `""` | Any OpenAI key with chat completions access |
| `OPENAI_MODEL` | No | `gpt-4o-mini` | Can use `gpt-4o` for better results |
| `SPOTIFY_CLIENT_ID` | For `discover` command | `""` | From developer.spotify.com |
| `SPOTIFY_CLIENT_SECRET` | For `discover` command | `""` | From developer.spotify.com |
| `DATABASE_PATH` | No | `data/deepcrate.sqlite` | Relative to working directory |

## Common Modifications

**Adding a new CLI command:** Add a `@app.command()` function in `cli.py`. Follow the existing pattern of importing dependencies inside the function body (keeps startup fast).

**Changing the LLM prompt:** Edit `planning/prompts.py`. The system prompt tells the LLM to respond in JSON. The library context is a formatted text list of tracks.

**Adjusting transition scoring:** Edit `planning/scoring.py`. The weights are in `transition_score()`. The weak transition threshold is `WEAK_THRESHOLD = 0.5` in `gaps.py`.

**Adding a new export format:** Create a new file in `export/`, follow the pattern of `m3u.py`. Add a new branch in the `export` command in `cli.py`.

**Supporting new audio formats:** Add the extension to `AUDIO_EXTENSIONS` in `analysis/scanner.py`. Librosa/soundfile handle the actual decoding.

## Gotchas

- The `data/` directory is gitignored and created at runtime by `_ensure_db()`.
- `librosa.load()` is called with `sr=22050, mono=True` — this is intentional for analysis speed. Don't change it without understanding the downstream impact on chromagram and beat tracking.
- The Rekordbox XML export uses `file://localhost` URL encoding for file paths. This is required by Rekordbox's import format.
- `detect_key()` returns Camelot notation directly (e.g., "8A"), not the musical key name. The mapping lives in `camelot.py`.
- All `db.py` functions create and close their own connections. This is safe for single-threaded CLI use but would need connection pooling if ever made concurrent.
