# C-256 result: work income vs crafting (no data change)

Rank-0 numbers, stones per day, ingredients bought at shop price, output sold at the
capped buy-back (`min(price/2, unit material cost x 1.3)`), success chance ignored.
Work = `work_income / 30` at rank 0 (rank 1 doubles it).

| Profession | work_income | work/day r0 (r1) | Best rank-0 recipe | craft margin/day | work / craft |
|---|---|---|---|---|---|
| Alchemist | 18 | 0.60 (1.2) | bone_setting_salve: cost 20, sells 2 x 13 x 1.3 = 26, 3 days | 2.0 | 0.30 |
| Blacksmith | 18 | 0.60 (1.2) | iron_sword: cost 22, sells 28.6, 4 days | 1.65 | 0.36 |
| Talisman Master | 15 | 0.50 (1.0) | golden_bell_talisman: cost 11, sells 14.3, 2 days | 1.65 | 0.30 |
| Array Master | 21 | 0.70 (1.4) | minor_spirit_gathering_array: cost 18, sells 23.4, 3 days | 1.8 | 0.39 |
| Beast Tamer | 15 | 0.50 (1.0) | spirit_beast_pellet: cost 16, sells 20.8, 3 days | 1.6 | 0.31 |
| Doctor | 15 | 0.50 (1.0) | no crafting recipes (treats patients) | n/a | n/a |

Gathering and selling in Qingshi (Village Herb Slope, 3 days a trip, non-spring):
expected sale value 26/18.5 = 1.4 stones per trip, about 0.47/day, below every work rate.

Finding: every crafter sits at 0.30-0.39 of its best bought-ingredient craft margin
(the spec band is a quarter to a half, work never above crafting), and work beats
gathering-and-selling. The sim's large Talisman d365 total (835) comes from 33
crafts a month plus commissions (2x reward), not from the work rate. Nothing to
raise, so `work_income` is unchanged; no balance numbers move.
