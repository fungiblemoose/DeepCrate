"""Tests for Camelot key wheel logic."""

from deepcrate.analysis.camelot import (
    compatible_keys,
    key_compatibility_score,
    key_name_to_camelot,
    parse_camelot,
)


def test_key_name_to_camelot():
    assert key_name_to_camelot("A minor") == "8A"
    assert key_name_to_camelot("C major") == "8B"
    assert key_name_to_camelot("G major") == "9B"
    assert key_name_to_camelot("F# minor") == "11A"
    assert key_name_to_camelot("nonexistent") == ""


def test_parse_camelot():
    assert parse_camelot("8A") == (8, "A")
    assert parse_camelot("12B") == (12, "B")
    assert parse_camelot("1a") == (1, "A")
    assert parse_camelot("") is None
    assert parse_camelot("13A") is None
    assert parse_camelot("0B") is None
    assert parse_camelot("XY") is None


def test_compatible_keys():
    compat = compatible_keys("8A")
    assert "8A" in compat  # same key
    assert "9A" in compat  # +1
    assert "7A" in compat  # -1
    assert "8B" in compat  # relative major

    # Edge case: wrapping around 12 → 1
    compat_12 = compatible_keys("12A")
    assert "12A" in compat_12
    assert "1A" in compat_12
    assert "11A" in compat_12
    assert "12B" in compat_12


def test_compatible_keys_wrapping_1():
    compat = compatible_keys("1A")
    assert "1A" in compat
    assert "2A" in compat
    assert "12A" in compat
    assert "1B" in compat


def test_key_compatibility_score():
    # Same key = 1.0
    assert key_compatibility_score("8A", "8A") == 1.0

    # Adjacent = 0.8
    assert key_compatibility_score("8A", "9A") == 0.8
    assert key_compatibility_score("8A", "7A") == 0.8
    assert key_compatibility_score("8A", "8B") == 0.8

    # Unknown key = neutral 0.5
    assert key_compatibility_score("", "8A") == 0.5
    assert key_compatibility_score("8A", "") == 0.5

    # Two steps away = 0.5
    assert key_compatibility_score("8A", "10A") == 0.5

    # Far away = 0.2
    assert key_compatibility_score("8A", "2A") == 0.2
