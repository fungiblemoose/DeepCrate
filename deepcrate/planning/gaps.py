"""Identify weak transitions and missing tracks in a set."""

from deepcrate.db import get_gaps, get_set_tracks, get_track_by_id, set_gaps
from deepcrate.models import Gap, Track, TransitionInfo
from deepcrate.planning.scoring import transition_score

WEAK_THRESHOLD = 0.5  # Transitions below this score are flagged


def analyze_gaps(set_id: int) -> list[TransitionInfo]:
    """Analyze all transitions in a set, returning weak ones."""
    set_tracks = get_set_tracks(set_id)
    if len(set_tracks) < 2:
        return []

    weak_transitions = []
    for i in range(len(set_tracks) - 1):
        track_a = get_track_by_id(set_tracks[i].track_id)
        track_b = get_track_by_id(set_tracks[i + 1].track_id)
        if not track_a or not track_b:
            continue

        score = transition_score(track_a, track_b)
        if score < WEAK_THRESHOLD:
            issues = []
            from deepcrate.analysis.camelot import key_compatibility_score
            from deepcrate.planning.scoring import bpm_compatibility_score, energy_flow_score

            if key_compatibility_score(track_a.musical_key, track_b.musical_key) < 0.5:
                issues.append(f"Key clash: {track_a.musical_key} → {track_b.musical_key}")
            if bpm_compatibility_score(track_a.bpm, track_b.bpm) < 0.5:
                issues.append(f"BPM jump: {track_a.bpm} → {track_b.bpm}")
            if energy_flow_score(track_a.energy_level, track_b.energy_level) < 0.5:
                issues.append(f"Energy jump: {track_a.energy_level:.1f} → {track_b.energy_level:.1f}")

            weak_transitions.append(TransitionInfo(
                from_track=track_a,
                to_track=track_b,
                score=score,
                issues=issues,
            ))

    # Store suggested gap fills in database
    gaps = []
    for i, trans in enumerate(weak_transitions):
        avg_bpm = (trans.from_track.bpm + trans.to_track.bpm) / 2
        avg_energy = (trans.from_track.energy_level + trans.to_track.energy_level) / 2

        # Suggest a key compatible with both tracks
        from deepcrate.analysis.camelot import compatible_keys
        keys_a = set(compatible_keys(trans.from_track.musical_key))
        keys_b = set(compatible_keys(trans.to_track.musical_key))
        common_keys = keys_a & keys_b
        suggested_key = sorted(common_keys)[0] if common_keys else trans.from_track.musical_key

        gaps.append(Gap(
            set_id=set_id,
            position=i + 1,
            suggested_bpm=round(avg_bpm, 1),
            suggested_key=suggested_key,
            suggested_energy=round(avg_energy, 2),
            suggested_vibe="bridge track",
        ))

    if gaps:
        set_gaps(set_id, gaps)

    return weak_transitions
