"""SQLite database schema and queries."""

import asyncio
import sqlite3
from pathlib import Path

from deepcrate.config import get_settings
from deepcrate.models import Gap, SetPlan, SetTrack, Track

SCHEMA = """
CREATE TABLE IF NOT EXISTS tracks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT UNIQUE NOT NULL,
    file_hash TEXT NOT NULL,
    title TEXT DEFAULT '',
    artist TEXT DEFAULT '',
    bpm REAL DEFAULT 0.0,
    musical_key TEXT DEFAULT '',
    energy_level REAL DEFAULT 0.0,
    duration REAL DEFAULT 0.0
);

CREATE TABLE IF NOT EXISTS sets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT DEFAULT '',
    target_duration INTEGER DEFAULT 60
);

CREATE TABLE IF NOT EXISTS set_tracks (
    set_id INTEGER NOT NULL,
    track_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    transition_score REAL DEFAULT 0.0,
    PRIMARY KEY (set_id, position),
    FOREIGN KEY (set_id) REFERENCES sets(id) ON DELETE CASCADE,
    FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS gaps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    set_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    suggested_bpm REAL DEFAULT 0.0,
    suggested_key TEXT DEFAULT '',
    suggested_energy REAL DEFAULT 0.0,
    suggested_vibe TEXT DEFAULT '',
    FOREIGN KEY (set_id) REFERENCES sets(id) ON DELETE CASCADE
);
"""


def _get_db_path() -> Path:
    settings = get_settings()
    return settings.db_path()


def _ensure_db() -> sqlite3.Connection:
    db_path = _get_db_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.executescript(SCHEMA)
    return conn


def get_connection() -> sqlite3.Connection:
    return _ensure_db()


# --- Track CRUD ---

def upsert_track(track: Track) -> Track:
    conn = get_connection()
    try:
        conn.execute(
            """INSERT INTO tracks (file_path, file_hash, title, artist, bpm, musical_key, energy_level, duration)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(file_path) DO UPDATE SET
                   file_hash=excluded.file_hash, title=excluded.title, artist=excluded.artist,
                   bpm=excluded.bpm, musical_key=excluded.musical_key,
                   energy_level=excluded.energy_level, duration=excluded.duration""",
            (track.file_path, track.file_hash, track.title, track.artist,
             track.bpm, track.musical_key, track.energy_level, track.duration),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM tracks WHERE file_path = ?", (track.file_path,)).fetchone()
        return Track(**dict(row))
    finally:
        conn.close()


def get_track_by_path(file_path: str) -> Track | None:
    conn = get_connection()
    try:
        row = conn.execute("SELECT * FROM tracks WHERE file_path = ?", (file_path,)).fetchone()
        return Track(**dict(row)) if row else None
    finally:
        conn.close()


def get_track_by_id(track_id: int) -> Track | None:
    conn = get_connection()
    try:
        row = conn.execute("SELECT * FROM tracks WHERE id = ?", (track_id,)).fetchone()
        return Track(**dict(row)) if row else None
    finally:
        conn.close()


def get_track_by_hash(file_hash: str) -> Track | None:
    conn = get_connection()
    try:
        row = conn.execute("SELECT * FROM tracks WHERE file_hash = ?", (file_hash,)).fetchone()
        return Track(**dict(row)) if row else None
    finally:
        conn.close()


def get_all_tracks() -> list[Track]:
    conn = get_connection()
    try:
        rows = conn.execute("SELECT * FROM tracks ORDER BY artist, title").fetchall()
        return [Track(**dict(r)) for r in rows]
    finally:
        conn.close()


def search_tracks(
    bpm_min: float | None = None,
    bpm_max: float | None = None,
    key: str | None = None,
    energy_min: float | None = None,
    energy_max: float | None = None,
    query: str | None = None,
) -> list[Track]:
    conn = get_connection()
    try:
        conditions = []
        params: list = []
        if bpm_min is not None:
            conditions.append("bpm >= ?")
            params.append(bpm_min)
        if bpm_max is not None:
            conditions.append("bpm <= ?")
            params.append(bpm_max)
        if key:
            conditions.append("musical_key = ?")
            params.append(key.upper())
        if energy_min is not None:
            conditions.append("energy_level >= ?")
            params.append(energy_min)
        if energy_max is not None:
            conditions.append("energy_level <= ?")
            params.append(energy_max)
        if query:
            conditions.append("(title LIKE ? OR artist LIKE ?)")
            params.extend([f"%{query}%", f"%{query}%"])

        where = " AND ".join(conditions) if conditions else "1=1"
        rows = conn.execute(f"SELECT * FROM tracks WHERE {where} ORDER BY bpm", params).fetchall()
        return [Track(**dict(r)) for r in rows]
    finally:
        conn.close()


# --- Set CRUD ---

def create_set(set_plan: SetPlan) -> SetPlan:
    conn = get_connection()
    try:
        conn.execute(
            "INSERT INTO sets (name, description, target_duration) VALUES (?, ?, ?)",
            (set_plan.name, set_plan.description, set_plan.target_duration),
        )
        conn.commit()
        row = conn.execute("SELECT * FROM sets WHERE name = ?", (set_plan.name,)).fetchone()
        return SetPlan(**dict(row))
    finally:
        conn.close()


def get_set_by_name(name: str) -> SetPlan | None:
    conn = get_connection()
    try:
        row = conn.execute("SELECT * FROM sets WHERE name = ?", (name,)).fetchone()
        return SetPlan(**dict(row)) if row else None
    finally:
        conn.close()


def get_all_sets() -> list[SetPlan]:
    conn = get_connection()
    try:
        rows = conn.execute("SELECT * FROM sets ORDER BY name").fetchall()
        return [SetPlan(**dict(r)) for r in rows]
    finally:
        conn.close()


def delete_set(name: str) -> bool:
    conn = get_connection()
    try:
        s = get_set_by_name(name)
        if not s or s.id is None:
            return False
        conn.execute("DELETE FROM set_tracks WHERE set_id = ?", (s.id,))
        conn.execute("DELETE FROM gaps WHERE set_id = ?", (s.id,))
        conn.execute("DELETE FROM sets WHERE id = ?", (s.id,))
        conn.commit()
        return True
    finally:
        conn.close()


# --- Set Tracks ---

def set_set_tracks(set_id: int, tracks: list[SetTrack]) -> None:
    conn = get_connection()
    try:
        conn.execute("DELETE FROM set_tracks WHERE set_id = ?", (set_id,))
        for st in tracks:
            conn.execute(
                "INSERT INTO set_tracks (set_id, track_id, position, transition_score) VALUES (?, ?, ?, ?)",
                (st.set_id, st.track_id, st.position, st.transition_score),
            )
        conn.commit()
    finally:
        conn.close()


def get_set_tracks(set_id: int) -> list[SetTrack]:
    conn = get_connection()
    try:
        rows = conn.execute(
            "SELECT * FROM set_tracks WHERE set_id = ? ORDER BY position", (set_id,)
        ).fetchall()
        return [SetTrack(**dict(r)) for r in rows]
    finally:
        conn.close()


# --- Gaps ---

def set_gaps(set_id: int, gaps: list[Gap]) -> None:
    conn = get_connection()
    try:
        conn.execute("DELETE FROM gaps WHERE set_id = ?", (set_id,))
        for g in gaps:
            conn.execute(
                "INSERT INTO gaps (set_id, position, suggested_bpm, suggested_key, suggested_energy, suggested_vibe) VALUES (?, ?, ?, ?, ?, ?)",
                (g.set_id, g.position, g.suggested_bpm, g.suggested_key, g.suggested_energy, g.suggested_vibe),
            )
        conn.commit()
    finally:
        conn.close()


def get_gaps(set_id: int) -> list[Gap]:
    conn = get_connection()
    try:
        rows = conn.execute(
            "SELECT * FROM gaps WHERE set_id = ? ORDER BY position", (set_id,)
        ).fetchall()
        return [Gap(**dict(r)) for r in rows]
    finally:
        conn.close()
