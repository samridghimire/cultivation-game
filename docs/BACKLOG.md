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
| F-005 | qa | todo | Balance sim script: `tests/sim/simulate_life.gd` runs N random lives headless and prints average age reaching each realm. Use it to sanity-check realms.json numbers. Owner goal: a player who keeps cultivating sensibly should almost never die of old age (each breakthrough must add comfortably more lifespan than the next realm takes to reach); old-age death should mainly come from burning lifespan (LIFE-001). |
| F-006 | world-ui | done | Settings: window mode, UI scale, volume buses (Master/Music/SFX), persisted to user://settings.cfg. |

## P1: Core gameplay loops
| id | role | status | task |
|---|---|---|---|
| G-001 | systems | done | Injuries (data/injuries.json, Injuries): failed breakthroughs and non-lethal defeats can injure; injuries slow cultivation and weaken combat until healed by time or pills (heal_injury effect). |
| G-001b | world-ui | done | Show injuries (Injuries.describe) on the character sheet and an injured icon/indicator in the HUD. |
| ART-001 | systems | done | Respawn core: data/artifact.json (lives, anchor slots per realm, start anchor, recharge cost growth, respawn qi/day costs), anchor places via `anchor_id` in regions.json, CreationArtifact system, GameState.bind_anchor/unbind_anchor/recharge_artifact, lethal combat deaths respawn at the latest anchor (old age stays final), EventBus.player_respawned. Anchor bind/release entries in anchor places' menus. Future violent deaths (e.g. Heavenly Tribulations) must go through GameState._die_violently. |
| ART-001b | world-ui | todo | Show artifact lives, recharge cost and bound anchors on the character sheet, plus a "Recharge artifact" action (GameState.recharge_artifact) until the full ART-005 screen exists. |
| G-002 | systems | done | Alchemy crafting: data/recipes.json (5 pill recipes from herbs), Alchemy.success_chance/check/known_recipes/refine, GameState.refine(recipe_id). Chance from Alchemist rank + Comprehension - difficulty; failure burns the herbs for half xp. The workshop lists refine options instead of Alchemist odd jobs. |
| G-002b | world-ui | todo | Alchemy screen (HUD modal, gamepad-friendly): list Alchemy.known_recipes (learned recipes, including ones above your rank) with ingredients (have/need), output, success chance, days; Refine button calls GameState.refine; locked recipes show their rank requirement. Replaces the plain workshop option list. |
| G-002c | systems | done | Recipe learning: only `starter` recipes (recipes.json) are known by default; others are learned from recipe scrolls (items with the `learn_recipe` effect, sold by merchants or looted; Jade Marrow from the Cave Guardian). CharacterData.known_recipes, Alchemy.knows/can_learn/learn; old saves keep the recipes their rank allowed. |
| G-002e | systems | todo | Pill quality: refining can yield a higher-grade pill on a great success (data-driven quality tiers in recipes.json, e.g. per-recipe `great_output` item and a great-success chance from the margin over the success roll). Add the higher-grade pill items. Depends on G-002c. |
| G-002d | content | todo | More alchemy recipes in data/recipes.json (new pills for qi, breakthroughs per realm, healing, combat buffs), using G-003 herbs; add new pill items to data/items.json. |
| LIFE-001 | systems | todo | Lifespan as a resource: add `lifespan_spent_years` and `lifespan_bonus_years` to CharacterData (save-compatible); Cultivation.lifespan_years accounts for both. Effects keys `burn_lifespan` (years) and `extend_lifespan` (years). Add a first forbidden secret art and an evil artifact weapon (techniques/items data) that burn lifespan for a large temporary power boost, plus a rare longevity pill. Warn the player in the UI text when an action costs lifespan. |
| FAM-001 | systems | todo | Character identity + generated NPCs: add `gender`, `surname`, `given_name`, `parents`/`children`/`spouses` (id arrays), `home_region`, `cultivates`, `diligence` to CharacterData (save-compatible). Make Npcs work for NPCs WITHOUT a data/npcs.json entry (behavior read from the CharacterData first, falling back to def). Add `Npcs.spawn(...)` with unique ids and `data/names.json` (Chinese surnames + given names) for name generation. Character creation lets the player pick gender and surname. |
| FAM-002 | systems | todo | Courtship & marriage: favor thresholds unlock courting, then proposing (GameState.propose(npc_id, rank) with rank "wife" or "concubine"). Per-gender rules in data/family.json: male = 1 main wife + up to N concubines (N grows with realm/clan status); female default = 1 Dao companion (configurable). Requirements/refusals: favor, realm gap, alignment clash, rank already taken, a proud NPC refuses to be a concubine. Spouses stored with their rank on both characters; dual cultivation bonus. Spawn a few eligible generated NPCs per region. Depends on FAM-001. |
| FAM-003 | systems | todo | Children & inheritance: couples can have children (pregnancy takes ~10 months of game time; MULTIPLE partners can be pregnant simultaneously, tracked per partner) and anyone can adopt. Children record their mother's spousal rank (heir priority: main wife's children first; the Patriarch can override). Child CharacterData inherits spiritual roots (mix of parents' elements/purity with mutation; rare genius chance) and attributes (parent average ± variance). Children age, and cultivation starts at 6+. Data-driven inheritance rules in data/family.json. Depends on FAM-001. |
| G-004 | systems | todo | Blacksmithing: forge artifacts (weapons/armor) from ores; artifacts have grade and stat bonuses. |
| G-005 | systems | todo | Talismans: craft single-use talismans with combat or utility effects. |
| G-006 | systems | todo | Arrays: place arrays that boost qi density at a location (e.g. Qi Gathering Array at your cave abode). |
| G-007 | systems | done | Doctor (Medicine): treat own injuries (scales with Doctor rank + Spirit), pay a clinic, treat patients for income + alignment. GameState.treat_own_injury / visit_clinic / treat_patients. |
| G-007b | world-ui | todo | Clinic place type in regions (village): options "Treat patients (1 month)", "Treat your <injury>" per injury, "Pay doctor (N stones)" via Medicine.clinic_cost. |
| G-007c | systems | todo | Doctors heal NPC injuries (alignment + favor). Depends on W-002 NPC model. |
| G-008 | systems | todo | Sect missions: sect members take missions from a mission board for contribution points; contribution shop sells techniques/pills/recipe scrolls (items with `learn_recipe`, G-002c). |
| G-009 | systems | todo | Reputation per sect/faction separate from alignment; evil deeds witnessed lower reputation with righteous sects. |
| G-010 | systems | todo | Cave abode: the player can claim a dwelling; place arrays, store items, cultivate in seclusion. |

## P1c: The Creation Artifact (owner priority, see DESIGN.md "The Creation Artifact")
ART-001 (respawn core) is in P1 because it is prioritized.

| id | role | status | task |
|---|---|---|---|
| ART-002 | systems | todo | Artifact functions framework: `data/artifact.json` "functions" list with unlock conditions (realm, artifact energy, flags) and effects. GameState.feed_artifact(item_id) converts spirit stones/treasures into artifact energy. Implement the first function: **Storage space** (separate item storage that is never dropped on death). Depends on ART-001. |
| ART-003 | systems | todo | Artifact function: **Appraisal** (reveals NPC roots/realm/talent and item grades in the UI via a query API) and **Inner world** (cultivate inside with high qi density and time dilation: N world days pass per M inner days). Depends on ART-002. |
| ART-004 | systems | todo | Artifact function: **Spirit garden** inside the inner world; plant herbs (G-003 herbs) that grow at accelerated speed and can be harvested. Depends on ART-003. |
| ART-005 | world-ui | todo | Artifact UI: an artifact screen (functions, locked/unlocked with conditions, energy, anchors list with bind/unbind), a respawn screen on death ("The artifact pulls your soul back...", choose an anchor), and anchor markers in the world. Gamepad friendly. Build incrementally as ART-001..004 land. |
| ART-006 | content | todo | Artifact lore and intro: an opening event at character creation where the mortal finds the artifact (dialogue file), artifact flavor text per function, and anchor-capable places across existing regions. |

## P1b: Family & Clan (owner priority, see DESIGN.md "Family & Clan system")
| id | role | status | task |
|---|---|---|---|
| FAM-004 | systems | todo | Training descendants: monthly training assignment for each child/disciple (cultivate, profession, study technique), teaching techniques the player knows, spending pills/stones on them; progress reported in the message log. Depends on FAM-003. |
| FAM-005 | systems | todo | Found a clan: requirements in data/family.json (e.g. Foundation Establishment, spirit stones, an estate in a region). Player becomes Patriarch/Matriarch; clan has a name (player surname), members (family, spouses, recruited retainers), ranks (Patriarch, Elder, Core, Outer), treasury, reputation. GameState.found_clan / recruit / promote. Depends on FAM-001. |
| FAM-006 | systems | todo | Clan estate: buildings in data/clan_buildings.json (ancestral hall, spirit field, alchemy room, protective array, library) with costs, build time and monthly effects (income, qi density, herb yield, training speed). Depends on FAM-005. |
| FAM-007 | systems | todo | Bloodlines: rare inheritable bloodline traits (data/bloodlines.json, e.g. Azure Dragon, Vermilion Phoenix) that can awaken at a realm and grant bonuses; inheritance odds through generations. Depends on FAM-003. |
| FAM-008 | systems | todo | Clan succession for NPC clans and heir designation: the Patriarch designates an heir (default: eldest child of the main wife); used by NPC clans when their patriarch dies and by the player's clan for an appointed Young Master/Mistress title. (The player does NOT permadie; see ART-001.) Depends on FAM-005. |
| FAM-009 | systems | todo | NPC clans (data/clans.json) with their own families; marriage alliances between clans; clan feuds and favor. Family members can join sects (clan + sect dual membership). Depends on FAM-005. |
| FAM-010 | world-ui | todo | Family tree & clan screen (HUD modal, gamepad-friendly): spouses, children with realm/age/roots, clan members, ranks, treasury, estate buildings; actions to assign training. Build incrementally as FAM-001..006 land. |
| FAM-011 | world-ui | todo | Courtship/marriage/childbirth/adoption interactions surfaced in NPC menus and dialogue; family home place type in regions where family members live. Depends on FAM-002/003. |
| FAM-012 | content | todo | Family content: names.json lists (100+ surnames, 200+ given names), eligible-NPC templates per region, data/family.json tuning, bloodline definitions, clan building definitions (once those systems exist). |
| FAM-013 | qa | todo | Generational sim: simulate 300 years with families headless; check population doesn't explode (cap/fertility tuning), save size stays reasonable, descendants' power curve is fun. Depends on FAM-003. |

## P2: World
| id | role | status | task |
|---|---|---|---|
| W-003b | world-ui | todo | Dialogue window UI: open on EventBus.dialogue_requested, render GameState.dialogue_view() ({id, speaker, text, choices[{index,label,disabled,reason}]}), call GameState.choose_dialogue(index), close on dialogue_ended. Follow src/ui/combat_report.gd; register in hud.gd. NPCs fall back to the choice menu until it exists. |
| W-004b | content | done | Added 22 encounters (now 42): righteous/neutral/demonic fortunes, realm-gated foes (demonic cultivator, jade python), NPC cameo flags (met_fox_spirit, met_peak_hermit). |
| W-004c | systems | todo | Encounters with player choices (e.g. help vs rob the traveller) and flag-checked follow-up encounters; currently each encounter has one outcome, so moral choices are split into separate encounters. |

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
