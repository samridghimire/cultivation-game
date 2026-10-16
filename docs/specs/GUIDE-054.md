# GUIDE-054: a Mortal crafter hears that they have not begun cultivating

## Why
QA-104 (`tools/godot.sh --headless --path . -s res://tests/sim/crafter_start.gd -- 10 365`): a new Alchemist who follows the
hints keeps earning (463 stones at day 365) but is still **Mortal** at day 365 in 8 of 10 seeds, 5-7 layers behind the
curious player. In 10 seeds no step had a cultivation line as the top hint: the herb, craft and order lines always come
first, and `_cultivation_hint` sits in the middle of `Guidance.hints` where the `limit` (5) often drops it.
Cultivation is the spine of the game (DESIGN.md pillar 2), so a crafter must be told, clearly and early, to start.

## Change (src/core/systems/guidance.gd)
1. Add `const MORTAL_CRAFTER_NUDGE_DAY := 30` with a `##` comment (game days before the nudge shows).
2. Add
   ```gdscript
   ## GUIDE-054: a Mortal who practises a craft and has played MORTAL_CRAFTER_NUDGE_DAY days hears where to begin
   ## cultivating. "" otherwise (not Mortal, no profession, too early, or `today` unknown).
   static func mortal_crafter_hint(c: CharacterData, data: GameData, region_id: String, today: int, flags: Dictionary = {}) -> String
   ```
   - Returns "" unless `c.realm_index == 0`, `not c.professions.is_empty()`, `today >= MORTAL_CRAFTER_NUDGE_DAY`.
   - Spot: `best_qi_in_region(c, data, region_id, flags)` (~503); use its `name` when non-empty, else "a meditation spot".
     When `region_id` is "" use "a meditation spot" and skip the estimate.
   - Estimate: `needed := maxf(Cultivation.qi_required(c, data) - c.qi, 0.0)`, `rate := Cultivation.qi_per_day(c, data, density)`
     with that spot's `density`; when rate > 0 add " (about %s)" with `Calendar.format_duration(ceili(needed / rate))`,
     exactly as `_cultivation_hint` does.
   - Text: `"You are still a mortal. Meditate at %s to begin cultivating%s; your craft will keep."`
3. In `hints()` (~27), append it right after the pregnancy line and **before** the newcomer hints, so it survives `limit`.
   Skip appending when it is "".
4. Do not change the journal unless the journal reuses `hints()` (check `journal_entries` callers; if the journal has a
   "Goal"/cultivation section that already says to meditate, leave it).

## Tests (tests/unit/test_guidance.gd)
- Mortal with a profession (use the GameState helper the other crafter tests use to take up Alchemist), `today` 30, in
  qingshi_village: `hints(...)` contains the line, its index is lower than any herb or craft hint, and it names the
  region's best meditation spot.
- Same player at day 10: absent.
- Qi Refining 1st Layer crafter at day 60: absent.
- Mortal with no profession at day 60: absent (the newcomer hints already cover them).
- With `limit` 1 and nothing more urgent (no injury, lifespan or duty), the nudge is the single hint returned.

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- Run `crafter_start.gd -- 3 365` once and paste the "cult-hint-steps" column in the commit: it must be > 0 now (the sim's
  policy is updated separately in QA-108, so stones/realm may not change yet).
- Follow-ups: whether a Qi Refining crafter who has not meditated for 30+ days should get a similar nudge (needs a
  "last meditated day" field, i.e. save state, so not in this task).
