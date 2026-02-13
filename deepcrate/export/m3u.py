"""M3U playlist export."""

from pathlib import Path

from deepcrate.db import get_set_by_name, get_set_tracks, get_track_by_id
from deepcrate.models import Track


def export_m3u(set_name: str, output_path: str | None = None) -> str | None:
    """Export a set as an M3U playlist file.

    Returns the output file path on success, None on failure.
    """
    set_plan = get_set_by_name(set_name)
    if not set_plan or set_plan.id is None:
        return None

    set_tracks = get_set_tracks(set_plan.id)
    if not set_tracks:
        return None

    tracks: list[Track] = []
    for st in set_tracks:
        track = get_track_by_id(st.track_id)
        if track:
            tracks.append(track)

    if not output_path:
        safe_name = set_name.replace(" ", "_").replace("/", "-")
        output_path = f"{safe_name}.m3u"

    lines = ["#EXTM3U", f"#PLAYLIST:{set_name}"]
    for track in tracks:
        duration = int(track.duration)
        display = track.display_name
        lines.append(f"#EXTINF:{duration},{display}")
        lines.append(track.file_path)

    Path(output_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output_path
