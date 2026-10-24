# GUIDE-169: a too-hard trial line leads with what to do

**Why.** WU-353's shot and review 20cc3d3: the HUD caps each hint at `HUD.HINT_MAX_CHARS` (120). The trial line today is
"The trial for Core Disciple is open at the Sect Recruitment Hall here: you face the Sword Pavilion Warden (Deadly, 2 in
100). A loss only injures you; practise Iron Fist to level 5 (now 2) or grow a stage first. The rank pays ...", so the HUD
cuts it after the odds and the advice (GUIDE-152/159/162/164) only ever shows in the journal.

**Change** (src/core/systems/guidance.gd, the trial branch around line 1640 and `_trial_advice` ~1700):
1. Split the "lever" out of `_trial_advice`: add
   `static func _trial_lever(c: CharacterData, data: GameData, region_id: String = "") -> String`
   returning only the action text of the branches that today produce " A loss only injures you; <X> first." (X =
   "practise Iron Fist to level 5 (now 2) or grow a stage", "learn a combat technique such as Iron Fist", "grow a stage",
   "learn a body technique such as Stone Skin Tempering and wear armor: Manual: Stone Skin Tempering (your sect treasury,
   45 contribution)" ...), without "A loss only injures you;" and without the trailing " first." / ".". "" for every
   other case (chance >= 0.5, the injury branch, the payoff branch, nothing to do). `_trial_advice` keeps returning exactly
   what it returns today, built from `_trial_lever` (so every existing caller and test stays the same).
2. In the trial line (the `"The trial for %s is open %s: %s.%s%s"` return): when `trial_odds < 0.5` and `_trial_lever` is
   not "", return instead
   `"The %s trial is too hard for now: %s first. It is open %s; you face %s, and a loss only injures you.%s"`
   with (rank name, lever, `_hall_where(...)`, `_trial_foe(...)`, pays_sentence). Example:
   "The Core Disciple trial is too hard for now: practise Iron Fist to level 5 (now 2) or grow a stage first. It is open
   at the Sect Recruitment Hall here; you face the Sword Pavilion Warden (Deadly, 2 in 100), and a loss only injures you."
   Every other case keeps today's text.
3. **Before editing, grep** `The trial for` and `trial is open` in src/ and tests/: drop/merge helpers (~2977), the journal
   (~3546), `--hint-shot` cases in tests/sim/screenshot_screens.gd and unit tests may match the old opening. Make them
   accept both openings (e.g. match `" trial "` plus the rank name) rather than only the new one. Update tests that pin
   the old full text of a too-hard trial to the new text.

**Tests** (tests/unit/test_guidance.gd, next to GUIDE-162/164's):
- Foundation Peak member, Iron Fist level 2 below typical, Stone Skin learned, armor worn, trial hopeless -> the trial hint
  begins "The Core Disciple trial is too hard for now: practise Iron Fist to level" and `HUD.cap_hint(line)` (or the
  same 120-char cap if the test cannot reach HUD) still contains "Iron Fist".
- A trial at >= 0.5 -> unchanged opening "The trial for".
- The thin-defence branch (no body art) -> the new line contains "learn a body technique".
- `_trial_advice` output unchanged for the GUIDE-152/159/162/164 cases (their existing tests stay green untouched).

**Acceptance:** ALL CHECKS PASSED; in the commit, paste the new line for the WU-353 shot's player and its length.
