# GUIDE-132: The breakthrough pill from the sect treasury

## Why
Planner trace 2026-10-23 10:10 (`-- 1 12 --curious --trace --seed=67`): an Azure Cloud **Inner Disciple** at the QR 9th
layer ends month 12 with **1730 sect contribution** (10-seed median 1346, QA-146) and 291 stones, and the goal line says
"Save for a Foundation Establishment Pill (+25 percent): 300 stones, you have 291. Sold at ...". But Azure Cloud's shop
(data/sects.json) sells that same pill for **250 contribution from rank 1** (Inner Disciple); Blood Lotus (Blood Disciple)
and Myriad Treasure Pavilion (Steward, 260) do too. No hint or goal says so, and stones are the scarce resource at the
bottleneck (DESIGN.md F-005d: "players hold ~170"). The contribution route already exists in game (mission board's
shop tab and the sect hall menu, `GameState.buy_with_contribution`); this only points at it.

## Changes (src/core/systems/guidance.gd)
1. New helper:
   ```gdscript
   ## GUIDE-132: {item_id, name, bonus, cost, min_rank} of the best breakthrough pill for the next realm in `c`'s sect
   ## shop (highest breakthrough_bonus, then cheapest), whatever c's rank; {} for rogues or when the shop has none.
   static func sect_pill_entry(c: CharacterData, data: GameData) -> Dictionary
   ```
   Walk `Sects.shop_items(c, data)`; an item qualifies when its `effects.breakthrough_realm` equals the next realm id
   (`data.realms[c.realm_index + 1].id`) and `effects.breakthrough_bonus > 0`. Return {} in the final realm.
2. New goal line:
   ```gdscript
   ## "Claim a Foundation Establishment Pill (+25 percent) from the sect treasury: 250 contribution, you have 1730."
   ## when `_pill_goal_applies` and c's rank reaches the entry's min_rank; "" otherwise.
   static func sect_pill_claim(c: CharacterData, data: GameData) -> String
   ```
   Use `Text.a(name)`, `roundi(bonus * 100)`, `Sects.contribution_balance(c)` (the spendable balance, not the total).
   When the balance already covers it, end with "you can claim it now." instead of "you have N." (mirrors "you can
   afford it now" in `pill_saving_goal`).
3. `pill_saving_goal`: when `sect_pill_entry` is non-empty but c's rank is below its `min_rank`, append
   `" As <Rank name> you could claim it for <cost> contribution."` (`(data.sects[c.sect["id"]] as SectDef).rank_name(min_rank)`).
   The line otherwise stays exactly as today (existing tests must not change).
4. The goals list (~line 2464, `var saving := pill_saving_goal(c, data)`): try `sect_pill_claim` first, then
   `pill_saving_goal`, then `pill_source_goal`.
5. Stones are no longer needed for the pill once the claim line shows:
   - `pill_gap_note` returns "" when `sect_pill_claim(c, data) != ""`.
   - GUIDE-126's qi-pill reserve (`qi_pill_offer`, grep `QI_BUY_KEEP` / `next_realm_pill_price` in it): reserve 0 for
     the pill (keep the clinic's 20) when `sect_pill_claim(c, data) != ""`.
   - `grep -n "pill_saving_goal\|next_realm_pill_price\|_pill_goal_applies" src/` and check every other caller; any
     that tells the player to save stones for the pill must stay silent while the claim line shows. List what you
     changed in the commit.

Do not change the sim (QA-148 does) or data.

## Tests (tests/unit/test_guidance.gd)
Build characters the way nearby pill-goal tests do (grep `pill_saving_goal` in tests/unit/).
- Azure Cloud rank 1 at QR 7th layer (stage 6), contribution 300, spent 0: the goals contain
  "Claim a Foundation Establishment Pill (+25 percent) from the sect treasury: 250 contribution, you can claim it now."
  and no "Save for".
- Same with contribution 600, spent 500 (balance 100): "..., you have 100."
- Azure Cloud rank 0 (outer disciple), same stage: the "Save for" line ends with
  "As Inner Disciple you could claim it for 250 contribution."
- Rogue: `pill_saving_goal` is byte-identical to today (no "claim").
- Blood Lotus rank 1: the claim line names 250 contribution.
- `pill_gap_note` is "" for the first case with 0 stones.
- QR 5th layer (stage 4, outside the last three stages): no claim line.

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- No existing test changed except where it asserted the absence of a goal it now legitimately gets (say which).
- Commit body: paste the goal lines for the seed-67 state (Inner Disciple, QR9, 1730 contribution, 291 stones) before/after
  (a quick throwaway test or the sim's `--trace`).
