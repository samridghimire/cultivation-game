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
| F-004b | world-ui | todo | Load screen in the main menu + pause menu using SaveManager.list_slots (F-004 backend). |
| F-005 | qa | todo | Balance sim script: `tests/sim/simulate_life.gd` runs N random lives headless and prints average age reaching each realm. Use it to sanity-check realms.json numbers. |
| F-006 | world-ui | done | Settings: window mode, UI scale, volume buses (Master/Music/SFX), persisted to user://settings.cfg. |

## P1: Core gameplay loops
| id | role | status | task |
|---|---|---|---|
| G-001 | systems | done | Injuries (data/injuries.json, Injuries): failed breakthroughs and non-lethal defeats can injure; injuries slow cultivation and weaken combat until healed by time or pills (heal_injury effect). |
| G-001b | world-ui | done | Show injuries (Injuries.describe) on the character sheet and an injured icon/indicator in the HUD. |
| G-002 | systems | todo | Alchemy crafting: recipes in data/recipes.json (herbs → pills), success chance from Alchemist rank + comprehension, failure wastes herbs. Replaces "work as Alchemist" XP-only loop. Herb ids (tags ["herb"]): spirit_herb, dew_grass, qi_condensing_grass, purple_cloud_mushroom, flame_lotus, ice_soul_flower, blood_ginseng, thousand_year_lingzhi; ores (tags ["ore"]): iron_essence, cold_iron, azure_crystal, star_silver (from W-002 branch). |
| G-004 | systems | todo | Blacksmithing: forge artifacts (weapons/armor) from ores; artifacts have grade and stat bonuses. |
| G-005 | systems | todo | Talismans: craft single-use talismans with combat or utility effects. |
| G-006 | systems | todo | Arrays: place arrays that boost qi density at a location (e.g. Qi Gathering Array at your cave abode). |
| G-007 | systems | done | Doctor (Medicine): treat own injuries (scales with Doctor rank + Spirit), pay a clinic, treat patients for income + alignment. GameState.treat_own_injury / visit_clinic / treat_patients. |
| G-007b | world-ui | todo | Clinic place type in regions (village): options "Treat patients (1 month)", "Treat your <injury>" per injury, "Pay doctor (N stones)" via Medicine.clinic_cost. |
| G-007c | systems | todo | Doctors heal NPC injuries (alignment + favor). Depends on W-002 NPC model. |
| G-008 | systems | todo | Sect missions: sect members take missions from a mission board for contribution points; contribution shop sells techniques/pills. |
| G-009 | systems | todo | Reputation per sect/faction separate from alignment; evil deeds witnessed lower reputation with righteous sects. |
| G-010 | systems | todo | Cave abode: the player can claim a dwelling; place arrays, store items, cultivate in seclusion. |

## P2: World
| id | role | status | task |
|---|---|---|---|
| W-003b | world-ui | todo | Dialogue window UI: open on EventBus.dialogue_requested, render GameState.dialogue_view() ({id, speaker, text, choices[{index,label,disabled,reason}]}), call GameState.choose_dialogue(index), close on dialogue_ended. Follow src/ui/combat_report.gd; register in hud.gd. NPCs fall back to the choice menu until it exists. |
| W-004b | content | todo | More encounter content in data/encounters.json (currently ~20), e.g. realm-scaled fortuitous encounters, sect-specific events, NPC cameos (set world flags NPC dialogue can check). |

## Local sessions
The local sessions that built combat/techniques, world/exploration/NPCs/dialogue and the UI screens have finished (2026-10-02); their work is on main and these areas are open to anyone. Add follow-up tasks above.

## Done
| id | task |
|---|---|
| G-003 | Herbs/ores (12 items, tags herb/ore), gather place type + gathering spots, Herb & Ore Stall that buys back at half price. |
| W-001 | Regions and travel: 4 data-driven regions (data/regions.json), world scene built per region, routes with days and realm gates (Exploration). |
| W-004 | Random encounters (data/encounters.json): tags, realm gates, Fortune-weighted, deadly lethal foes are evaded, combat via GameState.fight. |
| W-002 | NPC model: 5 named NPCs (data/npcs.json) age, cultivate monthly, break through and die; saved in GameState.npcs with per-NPC favor. |
| W-003 | Dialogue rules + data (src/core/systems/dialogue.gd, data/dialogue/*.json): entry conditions, hidden/locked choices, effects, favor, time. Inline choice-menu fallback. |
| F-000 | Project foundation: data-driven core systems, autoloads, village slice, save/load, tests, tooling. |
