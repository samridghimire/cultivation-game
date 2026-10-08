# STAT-001: Life record (systems)

A per-character tally of what the player has done, for the character sheet now and for the final-death / ascension summary
later (END-001, WU-003). The first-hour sim (QA-016) also needs fight counts.

## Core
New `src/core/systems/life_stats.gd`, `class_name LifeStats`, static functions only:
```gdscript
const KEYS: Array[String] = ["fights_won", "fights_lost", "threats_fled", "breakthroughs", "breakthroughs_failed",
	"tribulations_survived", "respawns", "items_crafted", "missions_done", "deeds_done", "encounters", "days_in_seclusion"]
const LABELS := {"fights_won": "Fights won", ...}  # one plain label per key
static func add(c: CharacterData, key: String, amount: int = 1) -> void   # push_error on an unknown key, ignore amount <= 0
static func get_stat(c: CharacterData, key: String) -> int
static func lines(c: CharacterData) -> PackedStringArray            # "Fights won: 12" for every non-zero key, KEYS order
```
`CharacterData.life_stats: Dictionary = {}` (key -> int). Add to `to_dict` / `from_dict` with default `{}` (convert values with
`int()` since JSON loads floats). No SAVE_VERSION bump needed (default handles old saves); the save-field guard test must pass.

## Hooks in GameState (find each function; count only the player's actions, not NPCs')
- `fight_enemy`: won → fights_won, lost (including a lethal death) → fights_lost.
- `face_threat(false)` (slipping away) → threats_fled.
- `attempt_breakthrough`: success → breakthroughs; failure → breakthroughs_failed.
- Tribulation success path (grep `tribulation_endured`) → tribulations_survived.
- Artifact respawn (grep `player_respawned.emit`) → respawns.
- Crafting success (GameState craft function, grep `Alchemy.craft` or `crafting`) → items_crafted by the output count.
- Mission completed → missions_done. Deed performed (`Deeds.perform` caller) → deeds_done.
- Exploration that triggers any encounter (story, choice or fight) → encounters.
- Closed-door cultivation / seclusion: add the days actually spent → days_in_seclusion.

## UI (small, in this task)
Character sheet (src/ui/character_sheet.gd): a "Life record" section listing `LifeStats.lines(player)`, or "Nothing of note
yet." when empty. Follow the sheet's existing section style.

## Tests
- tests/unit/test_life_stats.gd: add/get, unknown key ignored, lines skip zeros and keep KEYS order, to_dict/from_dict round
  trip, from_dict of a dict without `life_stats` gives {}.
- tests/unit/test_game_session.gd (or a new test file): a won fight and a lost non-lethal fight increment the counters; a
  breakthrough attempt increments one of the two breakthrough keys; slipping away from a threat increments threats_fled.

## Acceptance
tools/test.sh green; the sheet shows the section (cover it in an existing character sheet test if one builds the sheet).
