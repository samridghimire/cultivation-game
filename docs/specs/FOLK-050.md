# FOLK-050: Their own news

Role: systems. Reference: Tale of Immortal's NPCs who cultivate alongside you and remember you; Stardew Valley's
villagers who have lives of their own. Mechanics only, never names, story or art.

## Why
Friends react to the player's news (FOLK-046/047/049: sect join, promotion, breakthrough, wedding, contest), but
the reverse never happens. Named NPCs already cultivate off screen (`Npcs._live`, `cultivates: true` in
data/npcs.json: Xiao Ling starts a Mortal with diligence 0.6; Elder Mo, Herbalist Lan, Peddler Hei, ... are higher),
and their breakthroughs only reach the message log as "Rumours spread: X has broken through to Y!" or "X has begun
Qi Refining." A childhood friend who starts cultivating should be a moment the player can share.

## Rules
1. **Events carry a kind.** In `Npcs._live` add `"kind": "breakthrough"` (realm_index > 1) and `"kind": "qi_start"`
   (realm_index == 1) plus `"realm": result["realm_name"]` to the two success events. Nothing else in the event list
   changes (other consumers read `text` / `category`).
2. **Pending own-news.** New `CharacterData.friend_news: Dictionary` (npc_id -> {"kind": String, "realm": String,
   "day": int}), default `{}`, in `to_dict` / `from_dict` (old saves load with `{}`; no SAVE_VERSION bump needed if the
   field defaults, but add it to the save fixture test's expectations if that test lists fields).
   New static functions in `src/core/systems/folk_news.gd` (keep FolkNews the one place for news rules):
   - `queue_own(player, data, favor, npc_id, kind, realm, day) -> bool`: records it when the NPC is a **named** NPC
     (key of `data.npcs`), alive, and the player's favor with them is >= `folk_news.min_favor` (same threshold as
     FOLK-046), in any region. A newer own-news replaces an older one for that NPC. Returns true when recorded.
   - `has_own(player, npc_id, day) -> bool`: pending and not older than `folk_news.own_days` (new, default 30).
   - `take_own(player, data, npc_id, day) -> String`: returns the NPC's line once and clears it. Line from the new
     optional npcs.json field `own_news_lines` (keys `qi_start`, `breakthrough`; 1-3 strings each, tokens
     `{player}`, `{realm}`), picked by stable hash of npc_id + day like FolkNews.take (never GameState.rng);
     fallback lines in data/family.json `folk_news.own_fallback` (`qi_start`, `breakthrough`), neutral enough for
     anyone, e.g. "I did it, {player}. I have reached {realm}. You were the first one I wanted to tell."
   - Expired entries (older than own_days) are dropped by `take_own` / a cleanup call on month change.
3. **GameState wiring.** Where `Npcs.simulate` events are posted (game_state.gd ~5610), call `FolkNews.queue_own` for
   events with those kinds. When it records, post one log line that names the NPC and needs no pronoun, e.g.
   "Xiao Ling has begun Qi Refining. Visit to congratulate Xiao Ling." in category "info", instead of the old rumour
   line for that NPC (do not post both).
4. **Greeting and congratulating.** The next talk with that NPC: if `has_own`, the greeting is `take_own`'s line
   (FolkNews.take for the player's own news keeps priority if both are pending; the own-news then waits for the next
   talk). The same talk offers one extra dialogue/menu option "Congratulate <name>" (find how the FOLK-046 greeting is
   inserted at game_state.gd ~2250/2611 and how villager menu options are built in src/world; add the option through
   the existing interactable `get_options()` pattern): 0 days, +`folk_news.congratulate_favor` (new, default 3) favor
   once, a short reply line. A liked gift given while own-news is pending also counts as congratulating (+the same
   bonus on top of the gift) so gift-givers are not punished.
5. **Bubble.** GFX-249's news bubble shows for `has_own` too (extend whatever the world calls, likely
   `FolkNews.has_pending`; keep one function the world calls, e.g. make `has_pending` return true for either).
6. **GameData validation**: `own_news_lines` keys limited to `qi_start` / `breakthrough`, 1-3 strings, <= 140 chars;
   `folk_news.own_days` and `congratulate_favor` are ints > 0. Document all new fields in the files' `_doc`.

## Measure (paste in the commit)
Add `--own-news` to an existing long sim (tests/sim/first_hour.gd or rogue_season.gd; pick the one that already runs
a full GameState for 730 days) or a 20-line `tests/sim/own_news.gd`: seeds 1-6, 730 days, a player who lends a hand
to Xiao Ling weekly (so favor passes 40): list each recorded own-news (day, npc, kind). If **no** seed records one in
two years, still land the feature and write under `Follow-ups:` which NPC is closest (Xiao Ling's qi at day 730 vs
the Qi Refining threshold); do not change diligence or realms (that is a balance call for the planner).

## Tests (tests/unit/test_folk_news.gd or a new test_own_news.gd; one GameState integration test)
- queue_own records only named NPCs at favor >= min_favor; a generated NPC or a low-favor friend is ignored.
- take_own returns a line with {player}/{realm} filled and clears; a second call returns "".
- Entries older than own_days are not pending.
- Congratulate gives the favor once; a second congratulate does nothing; liked gift while pending adds the bonus.
- Save round trip keeps friend_news; a dict without the key loads as {}.
- Integration: force Xiao Ling's qi to the threshold, run GameState day advance until the event, assert the log line,
  `has_own`, the bubble query, the greeting and the congratulate favor gain.

## Out of scope
Content lines for each NPC (C-424 writes `own_news_lines`), the bubble/menu art (WU-629), NPCs joining sects.
Under ~350 changed lines. No balance values change (no balance run needed).
