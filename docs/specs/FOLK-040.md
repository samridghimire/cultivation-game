# FOLK-040: A birthday gift makes a sworn friend

Role: systems. Reference: Stardew Valley's birthday gifts (a liked gift on the birthday counts far more), mechanics only;
never its names, layout or art. Planner default (DESIGN.md, 2026-11-21 18:10).

## Why
FOLK-039 (4fe44a9) measured the hints player over 10 seeds x 24 months: Close friend 10/10 (median day 125), **Sworn friend 0/10**.
Gifts stop at `acquaintance.gift_max_favor` 50 (`Family.check_gift` refuses: "Gifts alone will not win more of their heart"), tea
(`folk_visits.call_on.max_favor`) stops at 80, Sworn friend is 85 (`folk_tiers`). The village book already prints
"Sworn friend at favor 85" on a Close friend's card (planner shot 2026-11-21 18:10 village_book_people.png), a goal the player cannot reach.

FOLK-022 already doubles the first gift on a villager's birthday (`Folk.birthday_gift_multiplier`, flag `BIRTHDAY_GIFT_PREFIX + id`
= the year, consumed in `GameState.give_gift` ~2592) and posts a `birthday_thanks` line. FOLK-040 only lets that one gift go past the cap.

## Rule
On a named villager's birthday, the **first liked gift of that year** (taste > 0, the same gift whose `cake` multiplier is 2) is accepted
even when favor >= `gift_max_favor`, and its gain is capped at `acquaintance.birthday_max_favor` (new, 90) instead of `gift_max_favor`.
Neutral gifts, a second gift that day, and every other day keep today's rules. Disliked gifts unchanged.

## Changes
1. `data/family.json` `acquaintance`: add `"birthday_max_favor": 90`; document it in the file's `_doc`
   ("acquaintance.birthday_max_favor (FOLK-040, optional, gift_max_favor..100; missing = gift_max_favor): the first liked gift on a
   villager's birthday counts up to this favor"). Validate it in the existing acquaintance check (family.gd ~482): int, >= gift_max_favor, <= 100.
2. `src/core/systems/family.gd`:
   - `static func gift_cap(data: GameData, birthday_like: bool) -> int`: `birthday_max_favor` (fallback `gift_max_favor`) when
     `birthday_like`, else `gift_max_favor`.
   - `check_gift(..., birthday_like: bool = false)` and `give_gift(..., birthday_like: bool = false)`: use `gift_cap` for the refusal and
     for `gain = mini(gain, cap - favor)`. `birthday_like` means "today is their birthday, the year's birthday gift is unused, and this item is liked";
     the caller computes it (core Family has no clock).
3. `src/core/systems/folk.gd`: `static func birthday_like(flags: Dictionary, npc: CharacterData, data: GameData, day: int, item_id: String) -> bool`
   = `birthday_gift_multiplier(flags, npc, data, day, false) > 1 and Family.gift_taste(data, npc.id, item_id) > 0`.
4. `src/autoload/game_state.gd` `give_gift` (~2575): compute `birthday_like` **before** the multiplier is consumed, pass it to
   `Family.give_gift`, and use `Family.gift_cap(data, birthday_like)` for `cap` (the festival/clan/karma/almanac clamps already use `cap - favor`).
   Every UI that greys out the Give option or previews favor (grep `check_gift(` in src/ui and src/world) passes the same flag, so the
   option is offered on the birthday.
5. Hint (src/core/systems/guidance.gd, GUIDE-278's "Grow closer" branch ~2345): when the player's best villager friend in reach has
   favor >= `gift_max_favor` and < the Sworn friend tier, and their birthday is within 14 days (`Folk.days_to_birthday`), and a liked
   item is in the bag or on sale in the current region, say "Grow closer: <Name>'s birthday in N days; a <Item> would mean a lot."
   (N = 0: "<Name>'s birthday is today: give the <Item>."). Add its short form in `_short_hint_base` (e.g. "Birthday: <Item> for <Name> (Nd)"),
   respecting GUIDE-283's no-cut-name guard. Off once the gift is given or the friend is Sworn.
6. Hints sim (`tests/sim/first_hour_presses.gd` or the hints player FOLK-039 extended): the hints player follows the new line (buys the
   liked item when on sale, keeps it, gives it on the day). Re-run FOLK-039's measure (10 seeds x 24 months) and paste close_friend and
   sworn_friend (median day, seeds reached) before/after in the commit. Target: sworn_friend in >= 5/10 seeds. If below, say why in
   Follow-ups (e.g. the liked item is not sold anywhere near: that is C-407's job) and do not change other numbers.

## Edge cases
- Favor 100 cap still holds (`clampi`).
- Family members (spouse, child, parent) unaffected: their favor rules are their own; skip them in the hint.
- A villager without a `birthday` (days_to_birthday -1): no change, no hint.
- Older saves: no new persistent state (the birthday flag already exists in world_flags), no SAVE_VERSION bump.
- The courtship proposal threshold (favor 60) can now be reached by one birthday gift from 50: acceptable (one day a year).

## Tests
- `tests/unit/test_family.gd` (or the existing gift test file): favor 60, liked item, birthday_like true -> accepted, gain capped at 90;
  birthday_like false -> refused; neutral item on the birthday -> refused.
- `tests/unit/test_game_session.gd`-style integration: put the clock on Hunter Ma's birthday, favor 80, give a liked item -> favor >= 85 and
  the "Hunter Ma: Sworn friend" tier-up fires (GameState._check_named_tiers, WU-589); a second liked gift the same day is refused.
- Guidance: the birthday line shows 14 days before with the item in the bag, not 15 days before, not when favor < gift_max_favor,
  not after the gift; short form <= 42 chars and keeps whole names.

## Acceptance
`tools/test.sh` prints ALL CHECKS PASSED; the commit has the before/after sworn_friend table. This changes a balance value the
balance sim does not measure (friendship only): no `tools/balance.sh --check` needed.
