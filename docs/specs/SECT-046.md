# SECT-046: Lessons from a lost trial

Reference: Tale of Immortal's sect trials you can retry (mechanics only), and this game's own FOUND-003 "lessons from failure"
for breakthroughs (`data.failure_bonus`, `Cultivation` line ~153), which the owner already accepted. Role: systems. Size: ~250 lines.

## Why
SECT-041 measured (sect_year.gd, seeds 1-3): Azure and Blood Lotus members now hold the next rank's contribution by day 35-57 but
are held back by the rank trial; only 4 of 9 seeds reach rank 1 by ~day 180 (target 6, latest 299, target 270). Losing a trial
today changes nothing for the next attempt except "train more". A loss should teach something, and the player should see it.

## Build
1. **Data** (`data/sects.json`): a new top-level object `"trial_lessons": {"per_loss": 0.06, "max": 0.18}` next to the sect
   entries (or inside whichever top-level key the file already uses for shared settings; read how `GameData` loads sects.json and
   skip non-sect keys the way `_doc` is skipped). Document it in `_doc`: "trial_lessons (SECT-046): each lost promotion trial
   for the rank you are trying for lowers that examiner's power by per_loss, up to max; reset when you are promoted."
   Validate in `GameData._validate()`: both floats, 0 <= per_loss <= max <= 0.5. Expose as `data.trial_lesson_per_loss` /
   `data.trial_lesson_max` (defaults 0.06 / 0.18 if the key is missing).
2. **State** (`CharacterData`): store losses in the existing `sect` dictionary as `sect["trial_losses"]` (int, default 0), so no
   new top-level field and no SAVE_VERSION bump; `from_dict` already keeps `sect` as is. Leaving a sect clears `sect`, which is fine.
3. **Rules** (`src/core/systems/sects.gd`):
   - `static func trial_lesson(c: CharacterData, data: GameData) -> float`: `minf(per_loss * trial_losses, max)`; 0.0 for rogues.
   - `static func note_trial_loss(c: CharacterData) -> void`: `sect["trial_losses"] += 1`.
   - `_set_rank` (promotion by any path) resets `sect["trial_losses"] = 0`.
   - `static func trial_foe(c: CharacterData, data: GameData) -> Dictionary`: `trial_opponent(data, trial_enemy(c, data),
     1.0 - trial_lesson(c, data))` ({} when no trial). Every caller that builds the examiner for a fight **or for odds** must use
     it: `GameState.attempt_promotion_trial`, the trial card's odds (`src/ui/trial_card.gd` `open()` computes a chance: find it),
     `Guidance._trial_advice` / the "trial is open" line (~3549, 3653), and the sims (`tests/sim/first_hour.gd`, `sect_year.gd`
     grep `trial_opponent`). Leave `trial_opponent` itself unchanged (the contest uses it).
4. **GameState.attempt_promotion_trial**: on a loss call `Sects.note_trial_loss(player)` before posting, and add to the warning:
   `"You learned the examiner's forms: next time they fight %d%% weaker."` using the new lesson value (only while it grew; at the
   cap say `"You know the examiner's forms as well as you can."`). Add `"lesson": Sects.trial_lesson(player, data)` to the
   `promotion_trial_lost` info dict (WU-624 shows it on the card).
5. **SECT-040's missing hint** (reviewer 2026-11-23: never applied): the Guidance trial line ends with the odds word, e.g.
   `"Trial for Inner Disciple: Fair odds"` (use `TrialCard.odds_line`'s words or the existing `Combat` chance-word helper Guidance
   uses for "Easy fight"), computed against `trial_foe` so the lesson shows up as better odds.

## Tests (`tests/unit/test_sects.gd` or a new `test_trial_lessons.gd`, plus `test_game_session.gd`)
- lesson is 0 with no losses; 0.06 after one; capped at 0.18 after five; 0 for a rogue.
- `trial_foe` power_mult is the enemy's own power_mult x (1 - lesson).
- promotion (pass_trial and auto_promote) resets losses to 0.
- GameState: losing a trial (rig the player very weak with a seeded rng) increments `trial_losses` and posts the lesson line;
  `Combat.win_chance` against `trial_foe` is higher after the loss than before.
- Guidance trial line contains "odds".
- GameData rejects `per_loss > max`.

## Acceptance
- `tools/test.sh` ALL CHECKS PASSED. Balance numbers change: run `tools/balance.sh --check`, refresh the sect year section, and
  paste the first-promotion day per sect/seed (sect_year.gd) before -> after in the commit. Target: 6 of 9 by ~day 180, latest <= 270.
  If the target is missed with these defaults, try per_loss 0.08 / max 0.24 once and report both.
