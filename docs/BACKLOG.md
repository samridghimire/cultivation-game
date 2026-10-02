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
| FAM-001 | systems | todo | Character identity + generated NPCs: add `gender`, `surname`, `given_name`, `parents`/`children`/`spouses` (id arrays), `home_region`, `cultivates`, `diligence` to CharacterData (save-compatible). Make Npcs work for NPCs WITHOUT a data/npcs.json entry (behavior read from the CharacterData first, falling back to def). Add `Npcs.spawn(...)` with unique ids and `data/names.json` (Chinese surnames + given names) for name generation. Character creation lets the player pick gender and surname. |
| FAM-002 | systems | todo | Courtship & marriage (Dao companions): favor thresholds unlock courting, then proposing marriage (GameState.propose(npc_id)); requirements and refusal reasons (favor, realm gap, alignment clash, already married). Married spouse is tracked on both characters; dual cultivation gives both a cultivation bonus when cultivating together. Spawn a few eligible generated NPCs per region. Depends on FAM-001. |
| FAM-003 | systems | todo | Children & inheritance: couples can have children (pregnancy takes ~10 months of game time) and anyone can adopt. Child CharacterData inherits spiritual roots (mix of parents' elements/purity with mutation; rare genius chance) and attributes (parent average ± variance). Children age, and cultivation starts at 6+. Data-driven inheritance rules in data/family.json. Depends on FAM-001. |
| G-004 | systems | todo | Blacksmithing: forge artifacts (weapons/armor) from ores; artifacts have grade and stat bonuses. |
| G-005 | systems | todo | Talismans: craft single-use talismans with combat or utility effects. |
| G-006 | systems | todo | Arrays: place arrays that boost qi density at a location (e.g. Qi Gathering Array at your cave abode). |
| G-007 | systems | done | Doctor (Medicine): treat own injuries (scales with Doctor rank + Spirit), pay a clinic, treat patients for income + alignment. GameState.treat_own_injury / visit_clinic / treat_patients. |
| G-007b | world-ui | todo | Clinic place type in regions (village): options "Treat patients (1 month)", "Treat your <injury>" per injury, "Pay doctor (N stones)" via Medicine.clinic_cost. |
| G-007c | systems | todo | Doctors heal NPC injuries (alignment + favor). Depends on W-002 NPC model. |
| G-008 | systems | todo | Sect missions: sect members take missions from a mission board for contribution points; contribution shop sells techniques/pills. |
| G-009 | systems | todo | Reputation per sect/faction separate from alignment; evil deeds witnessed lower reputation with righteous sects. |
| G-010 | systems | todo | Cave abode: the player can claim a dwelling; place arrays, store items, cultivate in seclusion. |

## P1b: Family & Clan (owner priority, see DESIGN.md "Family & Clan system")
| id | role | status | task |
|---|---|---|---|
| FAM-004 | systems | todo | Training descendants: monthly training assignment for each child/disciple (cultivate, profession, study technique), teaching techniques the player knows, spending pills/stones on them; progress reported in the message log. Depends on FAM-003. |
| FAM-005 | systems | todo | Found a clan: requirements in data/family.json (e.g. Foundation Establishment, spirit stones, an estate in a region). Player becomes Patriarch/Matriarch; clan has a name (player surname), members (family, spouses, recruited retainers), ranks (Patriarch, Elder, Core, Outer), treasury, reputation. GameState.found_clan / recruit / promote. Depends on FAM-001. |
| FAM-006 | systems | todo | Clan estate: buildings in data/clan_buildings.json (ancestral hall, spirit field, alchemy room, protective array, library) with costs, build time and monthly effects (income, qi density, herb yield, training speed). Depends on FAM-005. |
| FAM-007 | systems | todo | Bloodlines: rare inheritable bloodline traits (data/bloodlines.json, e.g. Azure Dragon, Vermilion Phoenix) that can awaken at a realm and grant bonuses; inheritance odds through generations. Depends on FAM-003. |
| FAM-008 | systems | todo | Legacy/succession (pending owner confirmation in DESIGN.md): on player death with a living heir, offer to continue as the heir; the clan, estate and world persist. Depends on FAM-003. |
| FAM-009 | systems | todo | NPC clans (data/clans.json) with their own families; marriage alliances between clans; clan feuds and favor. Family members can join sects (clan + sect dual membership). Depends on FAM-005. |
| FAM-010 | world-ui | todo | Family tree & clan screen (HUD modal, gamepad-friendly): spouses, children with realm/age/roots, clan members, ranks, treasury, estate buildings; actions to assign training. Build incrementally as FAM-001..006 land. |
| FAM-011 | world-ui | todo | Courtship/marriage/childbirth/adoption interactions surfaced in NPC menus and dialogue; family home place type in regions where family members live. Depends on FAM-002/003. |
| FAM-012 | content | todo | Family content: names.json lists (100+ surnames, 200+ given names), eligible-NPC templates per region, data/family.json tuning, bloodline definitions, clan building definitions (once those systems exist). |
| FAM-013 | qa | todo | Generational sim: simulate 300 years with families headless; check population doesn't explode (cap/fertility tuning), save size stays reasonable, descendants' power curve is fun. Depends on FAM-003. |

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
