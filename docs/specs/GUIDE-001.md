# GUIDE-001: Journal entries in core (systems)

The core half of the Journal screen (WU-007). WU-007 only renders what this returns, so all the "what can I do now?" logic
lives here, in `src/core/systems/guidance.gd`, with unit tests.

## API
```gdscript
## Every journal entry for `c`, in display order. Each entry is {section: String, text: String, tone: String}
## where tone is "normal", "warning" (urgent) or "dim" (waiting / on cooldown).
static func journal(c: CharacterData, data: GameData, flags: Dictionary, today: int, region_id: String,
		density: float = 1.0, people: Dictionary = {}, events: Array = [], clan: ClanData = null) -> Array[Dictionary]
```
Add a GameState wrapper with no side effects (no time, no posts):
```gdscript
func journal_entries() -> Array[Dictionary]   # passes player, data, world_flags, GameClock.total_days, current_region,
                                              # the same density the HUD hint uses, npcs, world_events, clan
```
Find the density the HUD hint already uses (grep `Guidance.hints(` in src/) and reuse that expression; if it is built inline,
move it into a small GameState helper and use it in both places.

## Sections (in this order; skip a section when it has no entries)
1. **"Next steps"**: every line of `hints(c, data, density, 99, people, flags, region_id)`. Tone "warning" for the lifespan and
   injury lines (they come first; match on the same conditions `hints` uses, e.g. `Cultivation.years_left(c, data) <=
   LIFESPAN_WARNING_YEARS` means the first line is a warning), "normal" otherwise.
2. **"Breakthrough"** (cultivators and mortals alike):
   - "Qi: 1,240 / 2,000 for <next stage label>" (use `Cultivation.qi_required` and the realm/stage label helper the
     character sheet uses).
   - If `Cultivation.is_at_bottleneck(c, data)`: "You are at a bottleneck: break through to go further." (tone warning).
   - Else "About N days of meditation here." from `Cultivation.days_to_bottleneck(c, data, density)` when > 0.
   - "Pills that help: Foundation Establishment Pill (held 1)" from `breakthrough_items(c, data)`, only if non-empty.
3. **"Sect"** (sect members only):
   - Duty: "Monthly duty: 40 / 60 contribution, 12 days left this month." from `Sects.monthly_duty`, `Sects.duty_progress`
     and `Calendar.DAYS_PER_MONTH - c.age_days % Calendar.DAYS_PER_MONTH` (months close on the player's `age_days`, see
     GameState `_on_days_advanced`). Tone warning if unmet with <= 7 days left; omit when duty is 0.
   - One line per mission in `Sects.available_missions(c, data)`: ready ones ("Ready: Patrol the Misty Peaks (7 days,
     danger: Even)", danger from `Sects.mission_danger` when the mission has an enemy) as normal, ones blocked only by
     cooldown ("Patrol the Misty Peaks: again in 9 days", `Sects.mission_cooldown_left > 0`) as dim. Skip missions blocked
     by anything else (rank, realm, items) to keep the list short.
4. **"Deeds"**: deeds on cooldown, "Donate stones to the poor: again in 14 days" (dim). Use the same arithmetic as
   `Deeds.check` (deeds.gd ~24-29: `c.deed_days[id] + cooldown_days - today`); extract it into
   `Deeds.cooldown_left(c, deed, today) -> int` and call it from both. Only deeds with `left > 0`.
5. **"World events"**: for each `WorldEvents.active_in(events, region_id)`: "<event name> here (N days left)" and, for each
   joinable kind ("tournament", "defence") the def has, "you can enter" when `WorldEvents.check_join(...) == ""`, else the
   reason. Events in other regions are not listed.
6. **"Milestones"**: "Milestones: 7 of 16" then the first 3 not-yet-earned milestones in data order as
   "<name>: <description>" (dim). Earned ids are in `c.milestones`.

## Edge cases
- `c.is_rogue()`: no Sect section.
- Mortal (realm_index 0): Breakthrough section still shows (qi toward Qi Refining).
- No events, no cooldowns: those sections are absent (no empty headers).
- Pure and deterministic: no rng, no mutation of `c` or `flags` (assert in a test that `c.to_dict()` is unchanged).

## Tests (tests/unit/test_journal.gd)
- A fresh newcomer: sections "Next steps", "Breakthrough", "Milestones" present; no "Sect".
- A sect member with duty 60 and 40 earned at day 25 of the month: duty line says "40 / 60" and is tone warning.
- A mission on cooldown shows "again in N days" (dim); a ready mission shows "Ready:".
- A deed done 3 days ago with cooldown_days 30 shows "again in 27 days"; `Deeds.check` still refuses it with the same count.
- An active tournament in the player's region shows "you can enter" for a QR player and the realm reason for a mortal.
- `journal` does not mutate the character.
- GameState integration (test_game_session.gd): `GameState.journal_entries()` on a new game is non-empty.

## Acceptance
`tools/test.sh` green. No UI changes in this task (WU-007 does the screen). Under ~300 lines.
