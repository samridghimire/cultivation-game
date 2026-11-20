# FOLK-036: A first friend you can see coming

Role: systems. Reference games: **Stardew Valley** (the friendship goal sits in plain sight and grows heart by heart) and
**Immortal Life** (helping with routines builds bonds). Mechanics only: no names, story or art.

## Why
FOLK-035 (5c6c986) added "Lend a hand" and a "Make a friend" hint. SIM-021 (8aa16cd) measured it:
- first Acquaintance: median day 328 -> **41** (good), but only because the sim reads the hint **uncapped**. In the real HUD
  the line is the **7th** hint at game start and the "Next steps" card shows 5 (`hud.gd` `GUIDE_MAX_LINES`), so a real
  player never sees it.
- first **Friend** tier (favor 40, `data/family.json` `folk_tiers[1]`): never in a year (0/10), because the hint stops at
  Acquaintance (`taste_hint_favor` 20).
- first_win worst day 34 -> 76: lending ahead of fights pushed the first win back.

## What to build
1. **Placement** (`src/core/systems/guidance.gd`, the hint list built around line ~1096): move the make-friend line up so it is
   within the first 4 lines at game start in Qingshi (day 0, fresh character), **but after** the first goal/fight line, so it
   never pushes the first easy fight out. Don't reorder anything else. If the simplest way is inserting it at a fixed index
   (`mini(2, out.size())`), do that.
2. **Second step to Friend**: `make_friend_hint` keeps going after the first Acquaintance:
   - no villager at favor >= 20: today's text, unchanged ("Make a friend: lend X a hand (..., favor a/20).").
   - some villager at >= 20 but none at the Friend tier min (read `folk_tiers[1].min`, 40, never hard-code): name the
     **highest-favor** villager below 40 who passes `Folk.lend_check`, text
     `"Become friends: lend %s a hand (%s, %s, favor %d/%d)."`. If that villager can't be lent to today (cooldown), but one of
     their liked gifts is in the bag, say `"Become friends: give %s the %s they like (favor %d/%d)."` (use the existing liked-gift
     lookup the gift hint uses; grep `taste_hint_favor` / `liked` in guidance.gd and folk.gd). Otherwise no line.
   - any villager at >= 40: no line.
   `lend_a_hand.max_favor` is 45, so lending alone reaches 40: no data change needed.
3. Keep the line's favor numbers live (they already are, from `favor`).

## Tests (tests/unit/test_guidance*.gd or a new test_make_friend_hint.gd)
- Fresh Qingshi character, day 0: the make-friend line is in `Guidance.hints(...)` (whatever the HUD list function is) at an
  index < 4 and after the first fight/goal line.
- One villager at favor 25, none at 40: "Become friends: lend <that villager>"; a villager at 41: no line.
- Cooldown + liked gift in bag: the gift form names the item.
- `tests/sim/first_hour.gd` already handles action `lend`; make sure it also acts on the "Become friends" line (same action;
  the gift form can map to the existing gift action if the sim has one, else skip it).

## Measure (commit message)
Run `tests/sim/first_hour_presses.gd` (10 seeds x 12 months) before/after and report: first Acquaintance, first Friend tier,
first_win (median/worst). Targets: first Friend median within 120 days; first_win worst back to <= 40 days. Refresh that
baseline section (`tools/balance.sh --section ...` as SIM-021 did). If a target misses, say so and propose numbers under
Follow-ups; don't change data/family.json.

## Acceptance
- A real player sees the friend line in the HUD at game start, and it leads them on to a Friend.
- tools/test.sh prints ALL CHECKS PASSED.
