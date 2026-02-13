"""Transition compatibility scoring between tracks."""

from deepcrate.analysis.camelot import key_compatibility_score
from deepcrate.models import Track


def bpm_compatibility_score(bpm_a: float, bpm_b: float) -> float:
    """Score BPM compatibility (0.0-1.0).

    Perfect match = 1.0, within 3 BPM = 0.9, within 6 = 0.7, etc.
    Also checks for half/double tempo compatibility.
    """
    if bpm_a <= 0 or bpm_b <= 0:
        return 0.5

    diff = abs(bpm_a - bpm_b)

    # Check half/double tempo
    half_diff = abs(bpm_a - bpm_b * 2)
    double_diff = abs(bpm_a * 2 - bpm_b)
    diff = min(diff, half_diff, double_diff)

    if diff <= 1:
        return 1.0
    elif diff <= 3:
        return 0.9
    elif diff <= 6:
        return 0.7
    elif diff <= 10:
        return 0.5
    elif diff <= 15:
        return 0.3
    else:
        return 0.1


def energy_flow_score(energy_a: float, energy_b: float, expected_direction: str = "any") -> float:
    """Score energy transition quality (0.0-1.0).

    Small changes are preferred over big jumps.
    expected_direction: 'up', 'down', or 'any'
    """
    diff = energy_b - energy_a
    abs_diff = abs(diff)

    # Penalize large jumps
    if abs_diff > 0.5:
        base = 0.2
    elif abs_diff > 0.3:
        base = 0.5
    elif abs_diff > 0.15:
        base = 0.7
    else:
        base = 0.9

    # Bonus/penalty for expected direction
    if expected_direction == "up" and diff > 0:
        base = min(base + 0.1, 1.0)
    elif expected_direction == "up" and diff < -0.1:
        base = max(base - 0.2, 0.0)
    elif expected_direction == "down" and diff < 0:
        base = min(base + 0.1, 1.0)
    elif expected_direction == "down" and diff > 0.1:
        base = max(base - 0.2, 0.0)

    return round(base, 2)


def transition_score(track_a: Track, track_b: Track, expected_direction: str = "any") -> float:
    """Overall transition score between two tracks (0.0-1.0).

    Weighted combination of key, BPM, and energy compatibility.
    """
    key_score = key_compatibility_score(track_a.musical_key, track_b.musical_key)
    bpm_score = bpm_compatibility_score(track_a.bpm, track_b.bpm)
    energy_score = energy_flow_score(track_a.energy_level, track_b.energy_level, expected_direction)

    # Weights: key matters most for harmonic mixing, BPM is critical, energy shapes the journey
    return round(0.4 * key_score + 0.35 * bpm_score + 0.25 * energy_score, 2)


def describe_transition(score: float) -> str:
    """Human-readable label for a transition score."""
    if score >= 0.85:
        return "Excellent"
    elif score >= 0.7:
        return "Good"
    elif score >= 0.5:
        return "Decent"
    elif score >= 0.3:
        return "Rough"
    else:
        return "Clash"
