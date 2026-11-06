# FOLK-015: The village talks about what you did

Role: systems. Reference: Stardew Valley (villagers mention what happened in town) and Tale of Immortal (NPCs remember
your deeds). Mechanics only: no names, lines or art from either.

## Why
A newcomer wins the dragon boat race, slays a great beast or restores a stage of the shrine, and the next day every villager
greets them with the same weather or favor line. The village should notice for a few days.

## Data (data/family.json, `folk_greetings`)
Add an optional `news` object: `{ "<kind>": [line, ...], ... }` plus `"news_days": 7`.
Kinds (start with these five): `contest_win`, `great_beast`, `shrine_stage`, `season_done`, `breakthrough`.
Lines may use `{player}` (already replaced by GameState.greeting_for) and `{subject}` (the contest, beast or realm name).
Seed 2 lines per kind yourself so the feature works; C-318 writes the rest. Document both fields in the file's `_doc`;
`Folk.validate_greetings` checks: `news` is a dictionary of known kinds -> non-empty arrays of non-empty strings, `news_days`
an int 1..30.

## State (world flags, no SAVE_VERSION bump)
`world_flags["village_news"] = {"kind": String, "subject": String, "region": String, "day": int}`: the newest notable
deed only (a newer one replaces it). Missing key = no news (old saves load unchanged).

## Core (src/core/systems/folk.gd)
- `static func record_news(flags: Dictionary, kind: String, subject: String, region_id: String, day: int) -> void`
- `static func news_line(npc: CharacterData, flags: Dictionary, data: GameData, region_id: String, day: int) -> String`:
  "" unless news exists, `day - news.day < news_days`, `region_id == news.region` (or the news region is one route away:
  `Exploration.is_nearby`) and `npc` is a villager (same predicate FOLK-014 uses for any_villager scenes; until it lands,
  not in a sect and not a data elder). Pick a line by `hash(npc.id + str(day))`, replace `{subject}`.
- In `Folk.greeting`: after celebration, birthday and shunned, and before weather/warm/cool, return the news line when not
  empty and the npc's favor is above the cool band (a villager who dislikes you does not praise you). Add the `region_id`
  parameter at the end with default "" (no news when "") so existing callers keep working; GameState.greeting_for passes
  `current_region`.

## Recording (src/autoload/game_state.gd; thin calls only)
- Festival contest won (in `festival_contest`, on a win): kind `contest_win`, subject = the contest/festival name.
- Great beast defeated (where a great roamer fight is won in `engage_roamer`): `great_beast`, subject = the beast's name.
- A shrine stage restored (where the season set completes and `restoration_stage` rises): `shrine_stage`, subject "the
  old shrine"; a season set finished without a new stage: `season_done`, subject = the season name.
- A major-realm breakthrough succeeds (`attempt_breakthrough`): `breakthrough`, subject = the new realm name.
Region = `current_region` at the time (for season/shrine news: Qingshi's region id from the restoration data).

## Tests (tests/unit/test_folk.gd or a new test_village_news.gd, plus test_game_session.gd)
- `news_line` returns a news line for a villager in the region on day+1, "" on day+news_days, "" in a far region, "" for
  a sect elder, "" when there is no news; `{subject}` replaced.
- `Folk.greeting` prefers a birthday over news, and news over the warm band; a cool-band villager gets the cool line.
- Validation rejects an unknown kind and an empty line.
- GameState integration: win a festival contest (reuse the FEST-010 test setup), then `greeting_for(<villager>)` the next
  day contains the subject.

## Acceptance
`tools/test.sh` passes. No balance run (no numbers change). The greeting bubble (WU-401) shows the news line with no UI change.
Follow-ups for C-318 (more lines) if you only seeded two.
