"""Audio analysis: BPM, key, energy, duration extraction using librosa."""

import hashlib
from pathlib import Path

import librosa
import mutagen
import numpy as np

from deepcrate.analysis.camelot import CHROMA_MAJOR, CHROMA_MINOR, key_name_to_camelot
from deepcrate.models import Track


def file_hash(path: Path) -> str:
    """Compute a fast hash of the first 1MB of a file for change detection."""
    h = hashlib.md5()
    with open(path, "rb") as f:
        h.update(f.read(1_048_576))
    return h.hexdigest()


def read_metadata(path: Path) -> dict[str, str]:
    """Read ID3/metadata tags from an audio file."""
    try:
        meta = mutagen.File(path, easy=True)
        if meta is None:
            return {}
        title = meta.get("title", [""])[0] if meta.get("title") else ""
        artist = meta.get("artist", [""])[0] if meta.get("artist") else ""
        return {"title": str(title), "artist": str(artist)}
    except Exception:
        return {}


def detect_bpm(y: np.ndarray, sr: int) -> float:
    """Detect BPM from audio signal."""
    tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
    bpm = float(np.atleast_1d(tempo)[0])
    return round(bpm, 1)


def detect_key(y: np.ndarray, sr: int) -> str:
    """Detect musical key and return Camelot notation."""
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr)
    chroma_avg = np.mean(chroma, axis=1)

    # Krumhansl-Kessler key profiles
    major_profile = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
    minor_profile = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])

    best_corr = -1.0
    best_key = ""

    for i in range(12):
        # Rotate chroma to test each root
        rotated = np.roll(chroma_avg, -i)
        major_corr = float(np.corrcoef(rotated, major_profile)[0, 1])
        minor_corr = float(np.corrcoef(rotated, minor_profile)[0, 1])

        if major_corr > best_corr:
            best_corr = major_corr
            best_key = CHROMA_MAJOR[i]
        if minor_corr > best_corr:
            best_corr = minor_corr
            best_key = CHROMA_MINOR[i]

    return key_name_to_camelot(best_key)


def detect_energy(y: np.ndarray, sr: int) -> float:
    """Estimate energy level (0.0-1.0) from RMS and spectral features."""
    rms = librosa.feature.rms(y=y)[0]
    spectral_centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]

    # Normalize RMS (typical range for music)
    rms_mean = float(np.mean(rms))
    rms_score = min(rms_mean / 0.15, 1.0)

    # Normalize spectral centroid (higher = brighter = more energy)
    centroid_mean = float(np.mean(spectral_centroid))
    centroid_score = min(centroid_mean / 5000.0, 1.0)

    # Weighted combination
    energy = 0.6 * rms_score + 0.4 * centroid_score
    return round(min(max(energy, 0.0), 1.0), 2)


def analyze_track(path: Path) -> Track:
    """Full analysis of a single audio track. Returns a Track model."""
    fhash = file_hash(path)
    metadata = read_metadata(path)

    # Load audio (mono, default sr)
    y, sr = librosa.load(str(path), sr=22050, mono=True)
    duration = float(librosa.get_duration(y=y, sr=sr))

    bpm = detect_bpm(y, sr)
    musical_key = detect_key(y, sr)
    energy = detect_energy(y, sr)

    title = metadata.get("title", "").strip()
    artist = metadata.get("artist", "").strip()

    # Fall back to filename when embedded tags are missing.
    if not title:
        title = path.stem

    return Track(
        file_path=str(path),
        file_hash=fhash,
        title=title,
        artist=artist,
        bpm=bpm,
        musical_key=musical_key,
        energy_level=energy,
        duration=duration,
    )
