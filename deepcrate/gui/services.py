"""Service helpers that connect GUI actions to DeepCrate core logic."""

from __future__ import annotations

from collections import OrderedDict
from pathlib import Path
from typing import Callable

from deepcrate.analysis.analyzer import analyze_track, file_hash
from deepcrate.analysis.scanner import find_audio_files
from deepcrate.db import (
    get_all_sets,
    get_all_tracks,
    get_gaps,
    get_set_by_name,
    get_set_tracks,
    get_track_by_id,
    get_track_by_path,
    search_tracks,
    upsert_track,
)
from deepcrate.discovery.spotify import search_tracks as spotify_search
from deepcrate.export.m3u import export_m3u
from deepcrate.export.rekordbox import export_rekordbox
from deepcrate.models import Gap, SetPlan, SetTrack, Track, TransitionInfo
from deepcrate.planning.gaps import analyze_gaps
from deepcrate.planning.planner import plan_set
from deepcrate.planning.scoring import describe_transition


def _parse_range(value: str | None, default_span: float) -> tuple[float | None, float | None]:
    if not value:
        return None, None

    parts = [p.strip() for p in value.split("-") if p.strip()]
    if not parts:
        return None, None

    low = float(parts[0])
    high = float(parts[1]) if len(parts) > 1 else low + default_span
    return low, high


def scan_directory(directory: str, progress_cb: Callable[[dict], None] | None = None) -> dict:
    """Scan and analyze all audio files in a directory."""
    dir_path = Path(directory).expanduser().resolve()
    if not dir_path.is_dir():
        raise ValueError(f"Not a directory: {dir_path}")

    files = find_audio_files(dir_path)
    total = len(files)

    analyzed = 0
    skipped = 0
    errors = 0

    for index, audio_file in enumerate(files, start=1):
        if progress_cb:
            progress_cb({"current": index, "total": total, "name": audio_file.name})

        existing = get_track_by_path(str(audio_file))
        current_hash = file_hash(audio_file)
        if existing and existing.file_hash == current_hash and (existing.title or "").strip():
            skipped += 1
            continue

        try:
            track = analyze_track(audio_file)
            upsert_track(track)
            analyzed += 1
        except Exception:
            errors += 1

    return {
        "directory": str(dir_path),
        "total": total,
        "analyzed": analyzed,
        "skipped": skipped,
        "errors": errors,
    }


def compute_library_stats() -> dict:
    tracks = get_all_tracks()
    if not tracks:
        return {
            "total": 0,
            "bpm_min": None,
            "bpm_max": None,
            "bpm_avg": None,
            "energy_min": None,
            "energy_max": None,
            "energy_avg": None,
            "duration_minutes": 0,
            "top_keys": [],
        }

    bpms = [t.bpm for t in tracks if t.bpm > 0]
    energies = [t.energy_level for t in tracks if t.energy_level > 0]
    keys: dict[str, int] = {}

    for track in tracks:
        if track.musical_key:
            keys[track.musical_key] = keys.get(track.musical_key, 0) + 1

    return {
        "total": len(tracks),
        "bpm_min": min(bpms) if bpms else None,
        "bpm_max": max(bpms) if bpms else None,
        "bpm_avg": sum(bpms) / len(bpms) if bpms else None,
        "energy_min": min(energies) if energies else None,
        "energy_max": max(energies) if energies else None,
        "energy_avg": sum(energies) / len(energies) if energies else None,
        "duration_minutes": int(sum(t.duration for t in tracks) // 60),
        "top_keys": sorted(keys.items(), key=lambda item: -item[1])[:10],
    }


def search_library(
    bpm_range: str | None,
    key: str | None,
    energy_range: str | None,
    query: str | None,
) -> list[Track]:
    bpm_min, bpm_max = _parse_range(bpm_range, 5.0)
    energy_min, energy_max = _parse_range(energy_range, 0.1)

    return search_tracks(
        bpm_min=bpm_min,
        bpm_max=bpm_max,
        key=key.strip().upper() if key else None,
        energy_min=energy_min,
        energy_max=energy_max,
        query=query.strip() if query else None,
    )


def create_set_plan(description: str, name: str, duration: int) -> SetPlan:
    result = plan_set(description, name, duration)
    if not result:
        raise RuntimeError("Failed to create set plan. Check API credentials and library contents.")
    return result


def get_set_tracks_detailed(name: str) -> list[tuple[SetTrack, Track, str]]:
    set_plan = get_set_by_name(name)
    if not set_plan or set_plan.id is None:
        return []

    rows: list[tuple[SetTrack, Track, str]] = []
    for set_track in get_set_tracks(set_plan.id):
        track = get_track_by_id(set_track.track_id)
        if track is None:
            continue
        transition_label = ""
        if set_track.position > 1:
            transition_label = f"{describe_transition(set_track.transition_score)} ({set_track.transition_score:.0%})"
        rows.append((set_track, track, transition_label))

    return rows


def list_sets() -> list[SetPlan]:
    return get_all_sets()


def analyze_set_gaps(name: str) -> tuple[list[TransitionInfo], list[Gap]]:
    set_plan = get_set_by_name(name)
    if not set_plan or set_plan.id is None:
        raise ValueError(f"Set not found: {name}")

    weak = analyze_gaps(set_plan.id)
    return weak, get_gaps(set_plan.id)


def discover_for_gap(name: str, gap_number: int, genre: str | None, limit: int) -> list[dict]:
    set_plan = get_set_by_name(name)
    if not set_plan or set_plan.id is None:
        raise ValueError(f"Set not found: {name}")

    gap_list = get_gaps(set_plan.id)
    if not gap_list:
        raise ValueError("No gaps found. Run gap analysis first.")

    if gap_number < 1 or gap_number > len(gap_list):
        raise ValueError(f"Gap number must be between 1 and {len(gap_list)}")

    target = gap_list[gap_number - 1]
    return spotify_search(
        bpm=target.suggested_bpm,
        energy=target.suggested_energy,
        genre=genre.strip() if genre else None,
        limit=limit,
    )


def export_set(name: str, fmt: str, output_path: str | None) -> str:
    fmt_normalized = fmt.strip().lower()
    if fmt_normalized == "m3u":
        exported = export_m3u(name, output_path)
    elif fmt_normalized in {"rekordbox", "xml"}:
        exported = export_rekordbox(name, output_path)
    else:
        raise ValueError("Unsupported export format")

    if not exported:
        raise RuntimeError("Failed to export set")

    return exported


def _env_file_path() -> Path:
    return Path(".env")


def load_preferences() -> dict[str, str]:
    defaults = {
        "OPENAI_API_KEY": "",
        "OPENAI_MODEL": "gpt-4o-mini",
        "SPOTIFY_CLIENT_ID": "",
        "SPOTIFY_CLIENT_SECRET": "",
        "DATABASE_PATH": "data/deepcrate.sqlite",
    }

    env_path = _env_file_path()
    if not env_path.exists():
        return defaults

    values = defaults.copy()
    for line in env_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = key.strip()
        if key in values:
            values[key] = value.strip()
    return values


def save_preferences(updates: dict[str, str]) -> Path:
    env_path = _env_file_path()
    merged = OrderedDict(load_preferences())
    for key, value in updates.items():
        merged[key] = value.strip()

    existing_other_lines: list[str] = []
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                existing_other_lines.append(line)
                continue
            key = stripped.split("=", 1)[0].strip()
            if key not in merged:
                existing_other_lines.append(line)

    lines = [f"{key}={value}" for key, value in merged.items()]
    if existing_other_lines:
        lines.append("")
        lines.extend(existing_other_lines)

    env_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    return env_path
