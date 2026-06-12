"""Camelot key wheel logic for harmonic mixing."""

# Mapping from musical key name to Camelot notation
# Standard pitch class → Camelot
KEY_TO_CAMELOT: dict[str, str] = {
    # Major keys
    "C major": "8B",   "G major": "9B",   "D major": "10B",
    "A major": "11B",  "E major": "12B",  "B major": "1B",
    "F# major": "2B",  "Gb major": "2B",  "Db major": "3B",
    "C# major": "3B",  "Ab major": "4B",  "Eb major": "5B",
    "Bb major": "6B",  "F major": "7B",
    # Minor keys
    "C minor": "5A",   "G minor": "6A",   "D minor": "7A",
    "A minor": "8A",   "E minor": "9A",   "B minor": "10A",
    "F# minor": "11A", "Gb minor": "11A", "Db minor": "12A",
    "C# minor": "12A", "Ab minor": "1A",  "Eb minor": "2A",
    "Bb minor": "3A",  "F minor": "4A",
}

CAMELOT_TO_KEY: dict[str, str] = {}
for k, v in KEY_TO_CAMELOT.items():
    if v not in CAMELOT_TO_KEY:
        CAMELOT_TO_KEY[v] = k

# Chromagram index (0=C, 1=C#, ...) → key name
CHROMA_MAJOR = [
    "C major", "C# major", "D major", "Eb major", "E major", "F major",
    "F# major", "G major", "Ab major", "A major", "Bb major", "B major",
]
CHROMA_MINOR = [
    "C minor", "C# minor", "D minor", "Eb minor", "E minor", "F minor",
    "F# minor", "G minor", "Ab minor", "A minor", "Bb minor", "B minor",
]


def key_name_to_camelot(key_name: str) -> str:
    """Convert a musical key name like 'A minor' to Camelot notation like '8A'."""
    return KEY_TO_CAMELOT.get(key_name, "")


def parse_camelot(camelot: str) -> tuple[int, str] | None:
    """Parse '8A' into (8, 'A'). Returns None if invalid."""
    camelot = camelot.strip().upper()
    if len(camelot) < 2:
        return None
    letter = camelot[-1]
    if letter not in ("A", "B"):
        return None
    try:
        number = int(camelot[:-1])
    except ValueError:
        return None
    if not 1 <= number <= 12:
        return None
    return (number, letter)


def compatible_keys(camelot: str) -> list[str]:
    """Return list of Camelot keys that are harmonically compatible.

    Compatible transitions (from Camelot wheel):
    - Same key (identity)
    - +1 semitone on wheel (e.g. 8A → 9A)
    - -1 semitone on wheel (e.g. 8A → 7A)
    - Relative major/minor (e.g. 8A → 8B)
    """
    parsed = parse_camelot(camelot)
    if parsed is None:
        return []

    number, letter = parsed
    results = [f"{number}{letter}"]  # same key

    # Adjacent on wheel
    up = (number % 12) + 1
    down = ((number - 2) % 12) + 1
    results.append(f"{up}{letter}")
    results.append(f"{down}{letter}")

    # Relative major/minor switch
    other = "B" if letter == "A" else "A"
    results.append(f"{number}{other}")

    return results


def key_compatibility_score(key_a: str, key_b: str) -> float:
    """Score from 0.0 to 1.0 for how compatible two Camelot keys are.

    1.0 = same key
    0.8 = adjacent or relative major/minor
    0.5 = two steps away
    0.0 = incompatible
    """
    if not key_a or not key_b:
        return 0.5  # unknown key, neutral score

    parsed_a = parse_camelot(key_a)
    parsed_b = parse_camelot(key_b)
    if parsed_a is None or parsed_b is None:
        return 0.5

    if key_a.upper() == key_b.upper():
        return 1.0

    if key_b.upper() in [k.upper() for k in compatible_keys(key_a)]:
        return 0.8

    # Two steps away on wheel
    num_a, let_a = parsed_a
    num_b, let_b = parsed_b
    dist = min(abs(num_a - num_b), 12 - abs(num_a - num_b))
    if dist == 2 and let_a == let_b:
        return 0.5

    return 0.2  # far away
