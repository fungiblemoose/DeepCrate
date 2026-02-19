# DeepCrate

AI-powered DJ set builder. Analyze your music library, plan sets with natural language, score transitions using harmonic mixing principles, and export to Rekordbox or M3U.

## Features

- **Library Analysis** — Scan audio files, extract BPM, musical key (Camelot notation), and energy levels using librosa and chromagrams
- **AI Set Planning** — Describe your set in natural language; OpenAI plans the tracklist using your library
- **Intelligent Scoring** — Evaluate transitions using harmonic mixing (Camelot wheel), BPM compatibility, and energy flow
- **Gap Analysis** — Identify weak transitions and suggest bridge tracks to fill them
- **Spotify Discovery** — Search Spotify to fill gaps in your library
- **Multi-Format Export** — Export to M3U (standard) or Rekordbox XML (professional DJ software)

## Example Walkthrough

Here's a complete session from raw music files to an exported DJ set:

```bash
# 1. Scan your library (takes a few minutes for large collections)
deepcrate scan ~/Music
# → Analyzed 847 tracks. Added 847, updated 0, skipped 0.

# 2. Check what's in your library
deepcrate stats
# → 847 tracks | BPM: 90–180 | Top keys: 8A, 9A, 2A

# 3. Find tracks by feel
deepcrate search --bpm 124-128 --key 8A --energy high
# → 23 tracks matching your filters

# 4. Plan a set with AI
deepcrate plan "dark minimal techno, steady 126 BPM, 60 minutes" \
  --name "Late Night" \
  --duration 60
# → Set "Late Night" created with 14 tracks. Avg transition score: 0.87

# 5. Review the set
deepcrate show "Late Night"

# 6. Find any weak spots
deepcrate gaps "Late Night"
# → Gap at position 7: score 0.42. Needs a track around 126 BPM in key 9A.

# 7. Search Spotify to fill it
deepcrate discover --name "Late Night" --gap 7

# 8. Export to Rekordbox
deepcrate export "Late Night" --format rekordbox
# → Exported to late_night.xml
```

## Quick Start

### Installation

```bash
git clone https://github.com/fungiblemoose/DeepCrate.git
cd DeepCrate
pip install -e .
```

**Requirements:** Python 3.12+

### Setup

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Add your API keys (all optional, but required for their respective features):
   ```
   OPENAI_API_KEY=sk-...          # For plan command (required)
   OPENAI_MODEL=gpt-4o-mini        # Default is fine, or use gpt-4o
   SPOTIFY_CLIENT_ID=...           # For discover command
   SPOTIFY_CLIENT_SECRET=...       # For discover command
   ```

3. Get your keys:
   - **OpenAI:** https://platform.openai.com/account/api-keys
   - **Spotify:** https://developer.spotify.com/dashboard

### Analyze Your Library

```bash
deepcrate scan ~/Music
```

This recursively finds all audio files, analyzes them (BPM, key, energy), and stores them in SQLite. Skips unchanged files on re-runs.

Supported formats: MP3, WAV, FLAC, M4A, OGG, and more (anything librosa handles).

### Plan a Set

```bash
deepcrate plan "uplifting techno set, 120 BPM, around 45 minutes" \
  --name "Friday Night" \
  --duration 45
```

The AI reads your library description and creates a tracklist with smooth transitions. Results are saved to the database.

### View Your Set

```bash
deepcrate show "Friday Night"
```

Displays the full tracklist with transition scores (0–1). A score of 1.0 is perfect; <0.5 is weak.

```
Track 1: Artist - Song [BPM 120, Key 8A] → Track 2
         BPM match: 0.95 | Key match: 1.0 | Energy: 0.92 | Overall: 0.95
```

### Find Weak Transitions

```bash
deepcrate gaps "Friday Night"
```

Analyzes all transitions and flags gaps (scores < 0.5) with suggestions for what kind of track would fit.

### Fill Gaps with Spotify

```bash
deepcrate discover --name "Friday Night" --gap 3
```

Searches Spotify for tracks that match the gap suggestions and adds them to the database.

## All Commands

| Command | Purpose |
|---------|---------|
| `deepcrate scan <directory>` | Analyze audio files in a folder and add to library |
| `deepcrate stats` | Show library overview (count, BPM range, key distribution) |
| `deepcrate search [--bpm MIN-MAX] [--key KEY] [--energy LEVEL] [-q TEXT]` | Filter and search your library |
| `deepcrate plan <description> --name NAME [--duration MINUTES]` | Create a DJ set using AI |
| `deepcrate show <set-name>` | Display a set with transition scores |
| `deepcrate gaps <set-name>` | Find weak transitions and gap suggestions |
| `deepcrate discover --name SET_NAME --gap GAP_NUMBER` | Search Spotify to fill a gap |
| `deepcrate export <set-name> --format [m3u\|rekordbox]` | Export set to file |

## How It Works

### Audio Analysis

Each track is analyzed for:
- **BPM** — Beat tracking via librosa's onset detection
- **Key** — Chromagram + Krumhansl-Kessler pitch class profiles, mapped to Camelot notation
- **Energy** — Combination of RMS amplitude and spectral centroid

### Transition Scoring

Transitions are scored (0–1) based on:
- **Key compatibility** (40%) — Uses the Camelot harmonic mixing wheel. Adjacent keys score high; clashing keys score low.
- **BPM matching** (35%) — Penalties for large tempo changes, with tolerance for half-tempo detection
- **Energy flow** (25%) — Gradual energy changes score higher than sudden jumps

### AI Planning

1. The AI receives your library context (track names, artists, BPM, keys)
2. You describe the set in natural language
3. OpenAI plans a tracklist as JSON
4. The tool validates and stores the set, then calculates transition scores

### Database

Four SQLite tables:
- **tracks** — Metadata from analysis (path, BPM, key, energy, duration)
- **sets** — Your planned sets (name, description, target duration)
- **set_tracks** — Tracks in each set, plus transition scores
- **gaps** — Gap analysis results and suggestions

## Configuration

All settings via `.env`:

```env
# OpenAI
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o-mini

# Spotify (optional)
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...

# Database (optional)
DATABASE_PATH=data/deepcrate.sqlite
```

## Development

### Running Tests

```bash
pytest tests/ -v
```

21 tests cover Camelot wheel logic, transition scoring, and audio analysis. No audio files or API keys required.

### Project Structure

```
deepcrate/
├── cli.py                 # All CLI commands
├── config.py              # .env settings
├── db.py                  # SQLite database layer
├── models.py              # Pydantic data models
├── analysis/              # Audio analysis (scanner, analyzer, Camelot)
├── planning/              # Set planning (AI prompts, scoring, gaps)
├── discovery/             # Spotify integration
└── export/                # M3U and Rekordbox XML export
```

See [HOW-IT-WORKS.md](HOW-IT-WORKS.md) for detailed technical documentation.

## Common Tasks

**Add a new export format:** Create a file in `export/`, follow the pattern of `m3u.py`.

**Adjust transition scoring:** Edit `deepcrate/planning/scoring.py`. Weights are in the `transition_score()` function.

**Change the AI prompt:** Edit `deepcrate/planning/prompts.py`.

**Support new audio formats:** Add the extension to `AUDIO_EXTENSIONS` in `deepcrate/analysis/scanner.py`.

## Gotchas

- **Half-tempo detection:** For drum and bass (often recorded at half tempo), the tool auto-detects and adjusts BPM. You can manually correct tracks with `deepcrate edit <track-id> --bpm X`.
- **Rekordbox paths:** File paths are exported as `file://localhost` URLs. This is required by Rekordbox's XML import format.
- **Camelot notation:** Keys are stored as Camelot notation (e.g., "8A"), not musical note names. Reference the Camelot wheel if needed.

## License

[Add your license here]

## Resources

- [Camelot Harmonic Mixing Wheel](https://www.pacemaker.net/)
- [OpenAI API Docs](https://platform.openai.com/docs)
- [Librosa Documentation](https://librosa.org/)
- [Rekordbox Import Format](https://www.pioneerdj.com/)
