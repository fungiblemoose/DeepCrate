"""Spotify search for gap-filling tracks."""

import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
from rich.console import Console

from deepcrate.config import get_settings

console = Console()


def _get_spotify_client() -> spotipy.Spotify | None:
    settings = get_settings()
    if not settings.spotify_client_id or not settings.spotify_client_secret:
        console.print("[red]Error:[/red] Spotify credentials not set in .env")
        return None

    auth = SpotifyClientCredentials(
        client_id=settings.spotify_client_id,
        client_secret=settings.spotify_client_secret,
    )
    return spotipy.Spotify(auth_manager=auth)


def search_tracks(
    bpm: float | None = None,
    genre: str | None = None,
    energy: float | None = None,
    query: str | None = None,
    limit: int = 10,
) -> list[dict]:
    """Search Spotify for tracks matching criteria.

    Returns list of dicts with: name, artist, bpm, key, energy, spotify_url
    """
    sp = _get_spotify_client()
    if sp is None:
        return []

    # Build search query
    parts = []
    if query:
        parts.append(query)
    if genre:
        parts.append(f"genre:{genre}")
    if not parts:
        parts.append("electronic")

    search_query = " ".join(parts)
    results = sp.search(q=search_query, type="track", limit=min(limit * 3, 50))

    tracks = []
    for item in results.get("tracks", {}).get("items", []):
        track_id = item["id"]

        # Get audio features for BPM/energy matching
        try:
            features = sp.audio_features([track_id])
            if not features or not features[0]:
                continue
            feat = features[0]
        except Exception:
            continue

        track_bpm = feat.get("tempo", 0)
        track_energy = feat.get("energy", 0)

        # Auto-double BPM if it looks like half-tempo DnB
        if bpm and bpm > 140 and track_bpm < 100:
            track_bpm *= 2

        # Filter by BPM if specified (within 5 BPM tolerance)
        if bpm and abs(track_bpm - bpm) > 5:
            continue

        # Filter by energy if specified (within 0.2 tolerance)
        if energy is not None and abs(track_energy - energy) > 0.2:
            continue

        artists = ", ".join(a["name"] for a in item.get("artists", []))
        tracks.append({
            "name": item["name"],
            "artist": artists,
            "bpm": round(track_bpm, 1),
            "energy": round(track_energy, 2),
            "key": feat.get("key", ""),
            "spotify_url": item["external_urls"].get("spotify", ""),
        })

        if len(tracks) >= limit:
            break

    return tracks
