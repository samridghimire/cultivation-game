# GUIDE-021: Fights you can win

**Role:** systems. **Size:** ~150 lines plus tests.

## Why
QA-052/QA-062: the curious player's deaths are fights taken at bad odds (the Mist Wolf mission at 18-35%), while fair
fights (rank-0 missions rated Even, the drunk bully bounty, Misty Forest boars) are scattered over the mission board,
the bounty board and exploration. A newcomer has no single place that says "this is a fight you can win now". The
journal gets one, built from ratings the game already computes, so learning a fighting style and practising it turns
into visible new options.

## What to build
`src/core/systems/guidance.gd`:

```gdscript
const FAIR_FIGHTS_MAX := 3
const FAIR_FIGHT_MIN_CHANCE := 0.7  # "Even" or better (Combat.label_for_chance)

## Up to FAIR_FIGHTS_MAX fights `c` can take now with a win chance >= FAIR_FIGHT_MIN_CHANCE,
## best chance first: [{text, chance, kind}] with kind "mission" | "bounty".
static func fair_fights(c: CharacterData, data: GameData, flags: Dictionary, today: int, region_id: String) -> Array[Dictionary]
```

Sources (only fights the player could start without travelling far):
1. **Sect missions**: for `id in Sects.available_missions(c, data, flags)` where the mission has an `enemy`, is not on
   cooldown (`Sects.mission_cooldown_left(c, id) == 0`) and `Sects.check_mission(c, data, id, flags) == ""`. Enemy dict:
   `data.enemies[mission["enemy"]]`. Text: `"Sect mission: %s (%s, %d%%)" % [mission name, label, pct]`.
2. **Bounties**: the player's active hunt (`Bounties.active(c, data, today)`, if any) and the first offer from
   `Bounties.offers(c, data, today, region_id)` whose region is `region_id` or nearby (`Exploration.is_nearby`), only
   if `Bounties.check_take(c, data, id, today) == ""` (skip the check for the active hunt). Enemy:
   `data.enemies[b["enemy"]]`. Text: `"Bounty: %s in %s (%s, %d%%)" % [enemy name, region name, label, pct]`; the active
   hunt says `"Your hunt: ..."` instead of `"Bounty: ..."`.

`chance := Combat.win_chance(c, data, enemy)`, `label := Combat.label_for_chance(chance)`, `pct := roundi(chance * 100)`.
Keep entries with `chance >= FAIR_FIGHT_MIN_CHANCE`, sort by chance descending (ties: text ascending, so it is
deterministic), cut to the max. Rogues simply get no missions.

Cost: each `win_chance` is 40 simulated fights. Cap the work: rate at most 8 candidates in total (missions first in
data order, then bounties).

## Where it shows
- `Guidance.journal(...)`: after `_opportunity_entries(...)`, add each as `_add(out, "Fights you can win", text, "normal")`.
  If the list is empty **and** the player knows no combat technique, add one dim line instead:
  `first_combat_hint(c, data, region_id)` (skip if that is "" too). Nothing else when empty.
- Check the journal screen (src/ui/journal_screen.gd) shows unknown sections (it probably iterates sections in order of
  first appearance; if it has a fixed section list, add "Fights you can win" after "Opportunities").

## Edge cases
- Missions without `enemy` (chores, guard duty without a fight) are skipped.
- A mission whose `requires_flag` is unset is already filtered by `available_missions`.
- The "Answer the Sect's Call" missions have `cooldown_days` 0: they appear whenever available and fair; fine.
- Lost-mission cooldown (MISS-001) is in `mission_cooldown_left`, so a just-lost mission does not show.

## Tests (tests/unit/test_guidance.gd or a new tests/unit/test_fair_fights.gd)
1. A Qi Refining stage-3 Azure Cloud disciple with Iron Fist level 3 + Stone Skin: `fair_fights` is non-empty, every
   entry has `chance >= 0.7`, sorted descending, size <= 3.
2. A bare Mortal rogue in Qingshi: `fair_fights` is empty; the journal has a "Fights you can win" line equal to
   `first_combat_hint(...)`.
3. A mission on cooldown (`c.mission_cooldowns[id] = c.age_days + 5`) is not listed.
4. An active bounty the player can win shows with "Your hunt:".
5. Determinism: two calls return equal arrays.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; the journal of a sect newcomer who has practised Iron Fist lists at least one
fair fight. Follow-ups: WU-125 puts the top entry on the HUD.
