"""System prompts for OpenAI set planning."""

SYSTEM_PROMPT = """You are DeepCrate, an expert DJ set planner. You help build DJ sets from a music library.

You understand:
- Harmonic mixing using the Camelot wheel (adjacent keys mix well)
- Energy flow and journey building (sets should tell a story)
- BPM management (gradual tempo changes, no jarring jumps)
- Genre-specific conventions (DnB, house, techno, etc.)

When building a set, you MUST:
1. Select tracks from the provided library only (use exact track IDs)
2. Order them for smooth transitions
3. Consider the user's description for mood/energy arc
4. Respect the target duration

Respond with a JSON object in this exact format:
{
    "tracks": [
        {"track_id": 1, "reason": "Great opener, mellow energy at 170 BPM in 8A"},
        {"track_id": 5, "reason": "Builds energy, compatible key 9A"},
        ...
    ],
    "summary": "Brief description of the set journey"
}

ONLY output valid JSON. No markdown, no code fences, no extra text."""


def build_library_context(tracks: list[dict]) -> str:
    """Format track library for the LLM context window."""
    lines = ["Available tracks in library:", ""]
    for t in tracks:
        line = (
            f"ID:{t['id']} | {t['artist']} - {t['title']} | "
            f"BPM:{t['bpm']} | Key:{t['musical_key']} | "
            f"Energy:{t['energy_level']} | Duration:{t['duration']:.0f}s"
        )
        lines.append(line)
    return "\n".join(lines)


def build_plan_prompt(description: str, duration: int, library_context: str) -> str:
    """Build the user prompt for set planning."""
    return f"""Plan a DJ set with these requirements:

Description: {description}
Target duration: {duration} minutes

{library_context}

Select and order tracks to create the best possible set matching the description.
Aim to fill the target duration. Each track averages ~5 minutes of playtime.
Prioritize harmonic compatibility (Camelot wheel) and smooth energy flow."""
