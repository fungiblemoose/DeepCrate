"""Tests for audio analyzer (unit tests that don't require audio files)."""

from pathlib import Path
from unittest.mock import patch

import numpy as np

from deepcrate.analysis.analyzer import detect_energy, detect_key, file_hash


def test_file_hash(tmp_path):
    """file_hash should produce consistent hashes."""
    test_file = tmp_path / "test.mp3"
    test_file.write_bytes(b"fake audio content for testing" * 100)

    hash1 = file_hash(test_file)
    hash2 = file_hash(test_file)
    assert hash1 == hash2
    assert len(hash1) == 32  # MD5 hex length


def test_file_hash_different_content(tmp_path):
    """Different content should produce different hashes."""
    file_a = tmp_path / "a.mp3"
    file_b = tmp_path / "b.mp3"
    file_a.write_bytes(b"content A" * 100)
    file_b.write_bytes(b"content B" * 100)

    assert file_hash(file_a) != file_hash(file_b)


def test_detect_key_returns_camelot():
    """detect_key should return a valid Camelot notation."""
    sr = 22050
    duration = 5.0
    # Generate a simple sine wave at A4 (440 Hz)
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)
    y = np.sin(2 * np.pi * 440 * t).astype(np.float32)

    key = detect_key(y, sr)
    # Should be a valid Camelot key (number + letter)
    assert len(key) >= 2
    assert key[-1] in ("A", "B")
    assert key[:-1].isdigit()


def test_detect_energy_range():
    """detect_energy should return a value between 0.0 and 1.0."""
    sr = 22050
    # Quiet signal
    y_quiet = np.random.randn(sr * 3).astype(np.float32) * 0.001
    energy_quiet = detect_energy(y_quiet, sr)
    assert 0.0 <= energy_quiet <= 1.0

    # Loud signal
    y_loud = np.random.randn(sr * 3).astype(np.float32) * 0.5
    energy_loud = detect_energy(y_loud, sr)
    assert 0.0 <= energy_loud <= 1.0

    # Loud should have higher energy than quiet
    assert energy_loud > energy_quiet
