# GUIDE-158: the sect treasury's faster method

**Why.** QA-156 (8064442): the curious sim meditates with no method (x1.0) for 3 years while an Azure Cloud Inner Disciple
can claim the Azure Cloud Heart Sutra (x1.6 through Core Formation) for 700 contribution; seeds end with 7000-10000 unspent.
Claiming it brings the Foundation median only ~8% sooner, so this is not a pacing decision for the owner (F-005d).
WU-348 shows the rate on the treasury screen, but nothing points the player at the screen.

**Change** (src/core/systems/guidance.gd):
1. `static func sect_method_offer(c: CharacterData, data: GameData) -> Dictionary` returning
   `{item_id, tech_id, cost, rate, current}` or {}:
   - {} for rogues.
   - Over `Sects.shop_items(c, data)`: entries whose item is a manual (`Items.manual_technique(data, item_id)` != "")
     of a technique with `Techniques.is_faster_method(c, data, tech_id)` (GUIDE-166, core).
   - Rank: `Sects.check_purchase(c, data, item_id)` must not fail on rank. If check_purchase only fails on the balance,
     the entry still counts (the line then says how much you have), any other failure skips it. Read check_purchase's
     messages to tell them apart, or compare `int(entry.get("min_rank", 0))` with `int(c.sect["rank"])` directly.
   - Reserve, as tests/sim/first_hour.gd `_buy_sect_method` does: while `c.breakthrough_pill == ""` and
     `breakthrough_items(c, data).is_empty()` and `sect_pill_entry(c, data)` is not empty, the balance after paying must
     still cover that pill's cost. A method that would eat the pill's contribution is not offered yet (no line).
   - Best = highest `Techniques.method_rate_of`, ties cheaper then id. `current` = `method_rate_of` of the main method.
2. `static func sect_method_hint(c: CharacterData, data: GameData) -> String`:
   "Your sect treasury hands out %s for %d contribution (you have %d): it gathers qi x%s, your method x%s."
   using the technique's name ("the Azure Cloud Heart Sutra" reads best: use `Text.a` or the item name if the name has no
   article; look at how WU-348's treasury row names it), `String.num(rate, 1)`; append " Learn it from the Inventory and set
   it as your main method on the Techniques screen." only when the balance covers the cost. "" when the offer is {}.
3. In `hints` (~59-80): append it after the thin-defence hint and before the crafter nudges. Add it to the journal's Next
   steps the way the treasury body-art line (GUIDE-157) is, if the journal lists that one separately.

**Tests** (tests/unit/test_guidance.gd): Azure Cloud Inner Disciple with no method and 2000 balance, pill already taken ->
line names the sutra, "x1.6" and "x1.0" and ends with the Techniques screen clause; balance 800 with the Foundation pill
(250) still to claim -> no line (700 + 250 > 800); balance 1000 with the pill still to claim -> line; already knows the
sutra -> no line; outer disciple whose rank is too low -> no line; rogue -> no line.

**Acceptance:** ALL CHECKS PASSED. If tools/balance.sh diffs only in hint wording, refresh the sections it names.
