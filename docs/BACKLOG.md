# Backlog

Work queue for agents. Pick the top `todo` task for your role. See CLAUDE.md, "Autonomous agent workflow".
Status: `todo` | `in-progress` (PR open) | `done` | `blocked` (needs a human answer, link the question).
Roles: `systems` (core rules + tests), `content` (data/*.json + small hooks), `world-ui` (scenes, UI, UX), `qa` (tests, bugs, balance).

## P0: Foundation hardening
| id | role | status | task |
|---|---|---|---|
| F-001 | qa | todo | Add GameState integration tests for join_sect, leave_sect, buy_item, use_item, work_profession (contribution + promotion). |
| F-002 | world-ui | done | Pause menu on Esc (Resume / Save / Load / Settings stub / Quit to menu) instead of instantly returning to the menu. |
| F-003 | world-ui | done | Breakthrough feedback: a short screen-flash / message banner on success and failure (listen to EventBus.breakthrough_attempted). |
| F-004 | systems | done | Multiple save slots with metadata: SaveManager.list_slots/read_meta/delete_save/next_free_slot/most_recent_slot. |
| F-004b | world-ui | in-progress (local UI session) | Load screen in the main menu + pause menu using SaveManager.list_slots (F-004 backend). |
| F-005 | qa | todo | Balance sim script: `tests/sim/simulate_life.gd` runs N random lives headless and prints average age reaching each realm. Use it to sanity-check realms.json numbers. |
| F-006 | world-ui | done | Settings: window mode, UI scale, volume buses (Master/Music/SFX), persisted to user://settings.cfg. |

## P1: Core gameplay loops
| id | role | status | task |
|---|---|---|---|
| G-001 | systems | done | Injuries (data/injuries.json, Injuries): failed breakthroughs and non-lethal defeats can injure; injuries slow cultivation and weaken combat until healed by time or pills (heal_injury effect). |
| G-001b | world-ui | todo | Show injuries (Injuries.describe) on the character sheet and an injured icon/indicator in the HUD. |
| G-002 | systems | todo | Alchemy crafting: recipes in data/recipes.json (herbs → pills), success chance from Alchemist rank + comprehension, failure wastes herbs. Replaces "work as Alchemist" XP-only loop. |
| G-003 | content | in-progress (local 2e) | Herbs and materials: add ~10 spirit herbs/ores to items.json with prices and a gathering spot interactable (forest). |
| G-004 | systems | todo | Blacksmithing: forge artifacts (weapons/armor) from ores; artifacts have grade and stat bonuses. |
| G-005 | systems | todo | Talismans: craft single-use talismans with combat or utility effects. |
| G-006 | systems | todo | Arrays: place arrays that boost qi density at a location (e.g. Qi Gathering Array at your cave abode). |
| G-007 | systems | todo | Doctor: heal injuries (self and NPCs) for alignment + income. Depends on G-001. |
| G-008 | systems | todo | Sect missions: sect members take missions from a mission board for contribution points; contribution shop sells techniques/pills. |
| G-009 | systems | todo | Reputation per sect/faction separate from alignment; evil deeds witnessed lower reputation with righteous sects. |
| G-010 | systems | todo | Cave abode: the player can claim a dwelling; place arrays, store items, cultivate in seclusion. |

## P2: World
| id | role | status | task |
|---|---|---|---|
| W-001 | world-ui | in-progress | Region map with travel between locations; travel takes days. (Local session: data/regions.json + Exploration.) |
| W-002 | systems | in-progress (local 2e) | NPC model: NPCs reuse CharacterData; they age, cultivate off-screen each month, and can die. |
| W-003 | world-ui | in-progress (local 2e; window UI: 55) | Dialogue system driven by data/dialogue/*.json with conditions (realm, alignment, flags) and effects. |
| W-004 | content | in-progress | Random encounters/events table using Effects. (Local session: data/encounters.json.) Follow-up: add more encounter content once merged. |

## Owned by local sessions (do not pick up from the cloud)
As of 2026-10-02, local interactive sessions were building these. Cloud agents should not start overlapping work:
- Combat + techniques: `combat.gd`, `techniques.gd`, `data/enemies.json`, `data/techniques.json`
- World/exploration: `src/world/**`, `exploration.gd`, `data/regions.json`, `data/encounters.json`
- UI: hud, character sheet, inventory screen, techniques screen, combat report

Once these land on main, cloud agents may add follow-up tasks for them above (bugs, content, balance).

## Done
| id | task |
|---|---|
| F-000 | Project foundation: data-driven core systems, autoloads, village slice, save/load, tests, tooling. |
