"""Tests for transition scoring."""

from deepcrate.models import Track
from deepcrate.planning.scoring import (
    bpm_compatibility_score,
    describe_transition,
    energy_flow_score,
    transition_score,
)


def _make_track(**kwargs) -> Track:
    defaults = {"file_path": "/test.mp3", "file_hash": "abc"}
    defaults.update(kwargs)
    return Track(**defaults)


def test_bpm_compatibility_exact():
    assert bpm_compatibility_score(174, 174) == 1.0


def test_bpm_compatibility_close():
    assert bpm_compatibility_score(174, 176) == 0.9


def test_bpm_compatibility_moderate():
    assert bpm_compatibility_score(174, 179) == 0.7


def test_bpm_compatibility_far():
    assert bpm_compatibility_score(174, 190) <= 0.1


def test_bpm_compatibility_half_tempo():
    # 87 BPM is half of 174 — should be detected
    score = bpm_compatibility_score(174, 87)
    assert score >= 0.9


def test_bpm_compatibility_zero():
    assert bpm_compatibility_score(0, 174) == 0.5


def test_energy_flow_smooth():
    assert energy_flow_score(0.5, 0.55) >= 0.8


def test_energy_flow_big_jump():
    assert energy_flow_score(0.2, 0.9) <= 0.3


def test_energy_flow_direction():
    # Expecting energy to go up
    up_score = energy_flow_score(0.3, 0.5, "up")
    down_score = energy_flow_score(0.3, 0.5, "down")
    assert up_score > down_score


def test_transition_score_perfect():
    a = _make_track(bpm=174, musical_key="8A", energy_level=0.5)
    b = _make_track(bpm=174, musical_key="8A", energy_level=0.55)
    score = transition_score(a, b)
    assert score >= 0.85


def test_transition_score_poor():
    a = _make_track(bpm=174, musical_key="8A", energy_level=0.2)
    b = _make_track(bpm=130, musical_key="2B", energy_level=0.9)
    score = transition_score(a, b)
    assert score <= 0.3


def test_describe_transition():
    assert describe_transition(0.9) == "Excellent"
    assert describe_transition(0.75) == "Good"
    assert describe_transition(0.55) == "Decent"
    assert describe_transition(0.35) == "Rough"
    assert describe_transition(0.1) == "Clash"
