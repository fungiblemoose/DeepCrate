"""LLM-based set planning using OpenAI."""

import json

from openai import OpenAI
from rich.console import Console

from deepcrate.config import get_settings
from deepcrate.db import (
    create_set,
    delete_set,
    get_all_tracks,
    get_set_by_name,
    get_track_by_id,
    search_tracks,
    set_set_tracks,
)
from deepcrate.models import SetPlan, SetTrack
from deepcrate.planning.prompts import SYSTEM_PROMPT, build_library_context, build_plan_prompt
from deepcrate.planning.scoring import transition_score

console = Console()


def _prefilter_tracks(description: str, all_tracks: list) -> list:
    """Pre-filter tracks to fit in LLM context window.

    For now, send all tracks if under 200; otherwise filter by keywords in description.
    """
    if len(all_tracks) <= 200:
        return all_tracks

    # Try to infer BPM range from description
    desc_lower = description.lower()
    bpm_min, bpm_max = None, None

    if any(w in desc_lower for w in ["dnb", "drum and bass", "drum & bass", "jungle"]):
        bpm_min, bpm_max = 160, 180
    elif any(w in desc_lower for w in ["house", "deep house"]):
        bpm_min, bpm_max = 118, 132
    elif any(w in desc_lower for w in ["techno"]):
        bpm_min, bpm_max = 128, 145
    elif any(w in desc_lower for w in ["dubstep"]):
        bpm_min, bpm_max = 138, 142

    if bpm_min is not None:
        filtered = search_tracks(bpm_min=bpm_min, bpm_max=bpm_max)
        if len(filtered) >= 10:
            return filtered

    # Fallback: return first 200 sorted by energy for variety
    return sorted(all_tracks, key=lambda t: t.energy_level)[:200]


def plan_set(description: str, name: str, duration: int = 60) -> SetPlan | None:
    """Use the LLM to plan a DJ set from the library."""
    settings = get_settings()
    if not settings.openai_api_key:
        console.print("[red]Error:[/red] OPENAI_API_KEY not set in .env")
        return None

    all_tracks = get_all_tracks()
    if not all_tracks:
        console.print("[red]Error:[/red] No tracks in library. Run 'deepcrate scan' first.")
        return None

    tracks = _prefilter_tracks(description, all_tracks)
    library_data = [
        {
            "id": t.id, "artist": t.artist, "title": t.title,
            "bpm": t.bpm, "musical_key": t.musical_key,
            "energy_level": t.energy_level, "duration": t.duration,
        }
        for t in tracks
    ]

    library_context = build_library_context(library_data)
    user_prompt = build_plan_prompt(description, duration, library_context)

    console.print(f"[dim]Sending {len(tracks)} tracks to {settings.openai_model}...[/dim]")

    client = OpenAI(api_key=settings.openai_api_key)
    response = client.chat.completions.create(
        model=settings.openai_model,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.7,
        max_tokens=2000,
    )

    raw = response.choices[0].message.content
    if not raw:
        console.print("[red]Error:[/red] Empty response from LLM")
        return None

    # Parse response JSON
    try:
        # Strip markdown fences if the model included them anyway
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
        result = json.loads(cleaned)
    except json.JSONDecodeError:
        console.print("[red]Error:[/red] Could not parse LLM response as JSON")
        console.print(f"[dim]{raw[:500]}[/dim]")
        return None

    # Delete existing set with same name
    delete_set(name)

    # Create set
    set_plan = create_set(SetPlan(name=name, description=description, target_duration=duration))
    if set_plan.id is None:
        console.print("[red]Error:[/red] Failed to create set in database")
        return None

    # Build set tracks with transition scores
    set_tracks = []
    prev_track = None
    for i, entry in enumerate(result.get("tracks", [])):
        track = get_track_by_id(entry["track_id"])
        if track is None:
            console.print(f"[yellow]Warning:[/yellow] Track ID {entry['track_id']} not found, skipping")
            continue

        score = 0.0
        if prev_track is not None:
            score = transition_score(prev_track, track)

        set_tracks.append(SetTrack(
            set_id=set_plan.id,
            track_id=track.id,
            position=len(set_tracks) + 1,
            transition_score=score,
        ))
        prev_track = track

    set_set_tracks(set_plan.id, set_tracks)

    summary = result.get("summary", "")
    if summary:
        console.print(f"\n[italic]{summary}[/italic]")

    return set_plan
