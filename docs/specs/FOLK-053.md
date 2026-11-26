# FOLK-053: Friends' news that actually reaches you

Role: systems. Reference: Tale of Immortal's NPCs who rise beside you; Stardew Valley's villagers' news (mechanics only).

## Problem
FOLK-050 queues a friend's own news (`FolkNews.queue_own`) only at the moment `Npcs.simulate` reports the milestone,
and only if favor is already >= `folk_news.min_favor` (40). FOLK-051's sim (`tests/sim/own_news.gd`, seeds 1-6, 730 days,
weekly lend-a-hand) measured **0 own news queued and 0 congratulations in every seed**: Xiao Ling begins Qi Refining before
her favor reaches 40, so the whole feature (bubble, congratulate card, journal row, GFX-262 light column) never fires in
practice. Also (reviewer note on GUIDE-293) the journal row names the friend's home region from data.npcs, not where they are.

## Change
1. **Remembered realm per friend.** New `CharacterData.friend_news_realm: Dictionary` (npc_id -> int realm_index last
   known to the player). `to_dict`/`from_dict` with default `{}`; no SAVE_VERSION bump (additive default).
2. **Seed it at the start.** `FolkNews.remember_realms(player, data, npcs) -> void`: for every named NPC id in `data.npcs`
   that exists in `npcs` and is alive, set `friend_news_realm[id] = npc.realm_index` **only if the id is absent**.
   Call it when a new game starts (where GameState builds the world NPCs) and once after a save loads (old saves: the
   current realms become the baseline silently, no burst of news).
3. **Catch up when favor allows.** `FolkNews.catch_up(player, data, favor, npcs, day) -> Array[String]` (pure, returns
   the npc ids it queued): for each id in `friend_news_realm`, with a living NPC that `Npcs.cultivates(...)`:
   - if `npc.realm_index > friend_news_realm[id]` and favor >= `min_favor`: queue via the existing `queue_own` with kind
     `"qi_start"` when the remembered realm was 0 (Mortal) and `npc.realm_index == 1`, else `"breakthrough"` with the
     current realm's name (`data.realms[npc.realm_index]` name, the same string `Npcs._live` puts in `event["realm"]`);
     then set `friend_news_realm[id] = npc.realm_index`.
   - if favor is below `min_favor`, leave the remembered realm unchanged (so it is caught up later).
   - Skip realms the NPC started the game with (that is what the seeding in step 2 is for).
4. **Keep the store in step with live events.** Where `queue_own` succeeds for a live event (game_state.gd ~5683), also set
   `friend_news_realm[npc_id] = npc.realm_index`. Call `catch_up` from the same daily handler, after the live events, and
   emit `EventBus.friend_rose` for each id it returns exactly like the live path does (so GFX-262's column plays).
5. **Where they are now.** `FolkNews.journal_rows` takes the region from `Npcs.region_of(npc, data)` when the NPC exists
   in `npcs`, falling back to the data.npcs region.

Only one catch-up news per friend per call; newer still replaces older (existing `queue_own` rule).

## Tests (tests/unit/test_folk_news.gd or the existing FOLK-050 test file)
- `test_catch_up_queues_missed_qi_start`: Xiao Ling remembered at 0, set to realm 1, favor 30 -> nothing queued and the
  remembered realm stays 0; favor 40 -> `qi_start` queued, remembered realm 1; a second call queues nothing.
- `test_seed_does_not_announce_starting_realms`: Elder Mo (starts above Mortal) after `remember_realms` and favor 60 ->
  `catch_up` queues nothing.
- `test_live_event_updates_the_memory`: a live `queue_own` path (GameState integration) leaves no duplicate catch-up.
- `test_old_save_without_memory_loads_quietly`: from_dict without the key, then remember_realms -> no news queued.
- `test_journal_row_names_current_region`: an NPC moved to another region shows that region.

## Measure
Re-run `tests/sim/own_news.gd` (seeds 1-6, 730 days). Acceptance: own news queued >= 1 in at least 5 of 6 seeds (Xiao
Ling's qi_start), and the sim congratulates when news is pending (extend the sim if it doesn't). Put the per-seed table
(queued, congratulated, day of Xiao Ling's news) in the commit message. No `tools/balance.sh --check` needed (no balance
numbers change).

## Acceptance
- `tools/test.sh` prints ALL CHECKS PASSED.
- The table above shows the news reaching the player.
- No SAVE_VERSION bump; old fixtures load.
