# FOLK-037: Tea with a friend

Role: systems. Reference: Stardew Valley's visits to a friend's house and Immortal Life's daily routines (mechanics only:
a repeatable, low-stakes way to grow a friendship you already have; never names, story or art).

## Why
FOLK-035 (lend a hand) carries a villager from 0 to favor 45 and FOLK-036 shows the path to Friend (40). Past 45 the only
ways up are liked gifts (GUIDE-278's "Grow closer" hint), festivals, and tea with a *visitor* (WORLD-007's `share_tea`, which
only works on the rare day a Friend happens to visit: `folk_visits.chance` 0.15, cooldown 30). So Close friend (60) and
Sworn friend (85) are almost out of reach without a stack of gifts, and the tier scenes and lessons at tiers 2-3 (Hunter Ma's
tracking lesson, his scarred bow) are rarely seen.

## The rule (planner default, DESIGN.md "Open design questions")
Once a villager is at least a Friend (`folk_tiers[1].min`, 40), you can go to them and **share tea** at most once every
7 days: 1 day, +3 favor (Charisma-scaled like lend), up to favor 80. Sworn friend (85) still needs a gift, a festival or a
scene, so it stays special. The existing visitor tea (a Friend dropping by) keeps working and does not use this cooldown.

## Data (data/family.json)
Add to `folk_visits` (keep every existing key):
```json
"call_on": {"days": 1, "cooldown_days": 7, "favor": 3, "min_tier": 1, "max_favor": 80}
```
Document `call_on` in the file's `_doc` (one line). Validate in `GameData._validate()`: if present, all five keys are ints,
`days >= 1`, `cooldown_days >= 1`, `favor >= 1`, `min_tier` is a valid index into `folk_tiers`, and `max_favor` is between
`folk_tiers[min_tier].min` and 100. Missing `call_on` = feature off (no menu entry, no hint).

## Core (src/core/systems/folk.gd), static, typed, `##` doc comments
- `static func call_on_check(c: CharacterData, npc: CharacterData, data: GameData, flags: Dictionary, today: int, favor: int, region_id: String = "") -> String`
  Mirror `lend_check` (same order of checks, reuse its family/region messages):
  rules empty / npc null / dead / not a named NPC -> "There is no one to call on."; family -> "Family has its own ways of
  spending the day."; other region -> "%s is not here."; `favor < folk_tiers[min_tier].min` -> "%s does not know you well
  enough to have you over." (name); `favor >= max_favor` -> "%s is always glad to see you; only something you share can
  bring you closer now."; cooldown from `flags["tea_" + npc.id]` -> "Again in N day(s)."; else "".
- `static func call_on_gain(c: CharacterData, data: GameData, favor: int) -> int` like `lend_gain`, using `call_on.favor`
  and `call_on.max_favor`.
Do NOT touch `player.folk_visit_day` (that is the visitor tea's per-day guard).

## GameState (src/autoload/game_state.gd)
`func call_on(npc_id: String) -> void` next to `lend_a_hand`, built the same way: `_can_act()`, check -> warning + return;
gain through the same festival/NpcClans/Karma scaling as `lend_a_hand` (copy those three lines, cap = `max_favor`);
`world_flags["tea_" + npc_id] = GameClock.total_days`; `npc_favor` += gain; post the line from `Folk.tea_line(data, name,
Family.favor_progress(...), today, season, false)` (the existing seasonal tea lines read right for a call); then the same
tail as lend: `_post_attitude_change`, `_friend_scene(npc_id)` (tier scenes fire when 60 is crossed), `_note_teacher_seen`,
`_teach_lessons(npc_id)`, `_start_time_skip()`, `_pass_time(days, "Tea")`. No rng draw (keep seeded sims stable; see C-404).
No tip roll (that stays a visitor-tea bonus). World flags are already saved, so no SAVE_VERSION change.

## Villager menu (src/world/interactables/npc.gd ~line 652)
After the "Lend a hand" entry: `"Share tea at %s's (1 day, favor %d)" % [npc.name, favor]` with `Folk.call_on_check(...)`
as the reason and `GameState.call_on.bind(npc_id)`. Show the entry only when `favor >= folk_tiers[min_tier].min` (a disabled
row for strangers is noise); when it is shown and disabled, the reason is the label hint as for lend. Keep the
"Share tea with X" visitor entry as it is; if both would show on the same day, show only the visitor one.

## Hint (src/core/systems/guidance.gd, GUIDE-278's "Grow closer" line)
Today: "Grow closer: give X the Y they like (favor a/60)". New order: if `call_on_check` passes for the highest-favor Friend
in the region -> "Grow closer: share tea at X's (favor a/60)"; else the gift branch as now; else nothing. Keep the line at the
same index and the same off-switch (any Close friend exists). Update the hints player in tests/sim/first_hour.gd so it acts
on the new line (find where GUIDE-278's line is matched: grep "Grow closer").

## Tests (tests/unit/)
- test_folk.gd (or the file holding lend_check tests): call_on_check returns "" at favor 40 in region, the right reason for
  favor 39, favor 80, wrong region, family member, and 3 days after a call; call_on_gain respects max_favor (favor 79 -> 1).
- test_game_session.gd: `GameState.call_on` raises favor by the gain, sets `tea_<id>`, passes 1 day, and crossing 60 fires
  the Close friend tier line; a second call the next day posts the cooldown warning and passes no time.
- GameData rejects `call_on.max_favor` below the tier min and a missing key.
- Guidance: a Friend (45) in region with no cooldown -> "Grow closer: share tea at"; on cooldown with a liked gift in the bag
  -> the gift line.

## Measure (commit message)
Add a `close_friend` milestone (first villager at `folk_tiers[2].min`) to tests/sim/first_hour.gd MILESTONES and run
`first_hour_presses.gd -- 10 12` before (main) and after. Paste both tables. Target: close_friend reached in >= 8/10 seeds
within 12 months, first_friend and first_win no worse than before. Refresh the first_hour_presses baseline section
(`tools/balance.sh --section`; a favor change does not need the full `--check`).

## Acceptance
tools/test.sh prints ALL CHECKS PASSED; the numbers above are in the commit message.
