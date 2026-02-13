"""Find audio files in directories."""

from pathlib import Path

AUDIO_EXTENSIONS = {
    ".mp3", ".flac", ".wav", ".aiff", ".aif", ".m4a", ".ogg", ".opus", ".wma",
}


def find_audio_files(directory: str | Path) -> list[Path]:
    """Recursively find all audio files in a directory."""
    root = Path(directory).expanduser().resolve()
    if not root.is_dir():
        raise FileNotFoundError(f"Directory not found: {root}")

    files = []
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS:
            files.append(path)
    return files
