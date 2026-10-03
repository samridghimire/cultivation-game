# Backlog

Work queue for agents. Pick the top `todo` task for your role (tables are in priority order, top first). See CLAUDE.md, "Autonomous agent workflow".
Status: `todo` | `in-progress` (PR open) | `done` | `blocked` (needs a human answer, link the question).
Roles: `systems` (core rules + tests), `content` (data/*.json + small hooks), `world-ui` (scenes, UI, UX), `qa` (tests, bugs, balance).

> **Producer note (2026-10-03):** Family (courtship, marriage, dual cultivation, children), medicine, equipment and combat talismans
> all exist in GameState but **none of them can be reached in-game yet**. Until P0 is cleared, world-ui agents should take P0 tasks first,
> and systems agents should prefer small tasks that unblock or complete a loop over opening new systems.

## P0: Close the loop (surface what is already built)
| id | role | status | task |
|---|---|---|---|
| FAM-002d | world-ui | todo | NPC menu entries (src/world/interactables/npc.gd get_options): "Court <name>" (GameState.court) once favor allows, and "Propose as <rank>" per Family.ranks(player gender) with Family.check_proposal reasons shown on disabled entries. Works for both def NPCs and generated NPCs (FAM-002f). Add a scene/menu test. |
| FAM-002h | systems | todo | Favor with generated NPCs: they have no dialogue, so nothing raises favor to the courtship threshold (family.json courtship.min_favor). Add a generic interaction, e.g. GameState.chat(npc_id) (a few days, small favor scaled by Charisma, capped) and/or gifting items, rules in data/family.json, so FAM-002d Court/Propose entries become reachable. |
| FAM-003c | world-ui | todo | "Try for a child with <spouse>" entry (GameState.try_for_child, Children.check_conception reason shown when unavailable) next to dual cultivation, and pregnancy (days left) + children by name on the character sheet. |
| G-004b | world-ui | todo | Show equipped weapon/armor with Equipment.describe_stats on the character sheet with Unequip buttons (GameState.unequip), and equip stats + an "Equip" label instead of "Use" for equipment in the inventory screen (GameState.equip_item). |
| G-005d | world-ui | todo | Ready/unready combat talismans (items with a `combat` block) from the inventory screen via GameState.ready_talisman/unready_talisman, show the readied list (max CombatTalismans.MAX_READIED) and the talisman kind/power (CombatTalismans.amount) in item details. |
| W-003b | world-ui | todo | Dialogue window UI: open on EventBus.dialogue_requested, render GameState.dialogue_view() ({id, speaker, text, choices[{index,label,disabled,reason}]}), call GameState.choose_dialogue(index), close on dialogue_ended. Follow src/ui/combat_report.gd; register in hud.gd. NPCs fall back to the choice menu until it exists. |
| G-007b | world-ui | todo | Clinic: new `clinic` place type (interactable in src/world/interactables, registered like workshop) with options "Treat patients (1 month)" (GameState.treat_patients), "Treat your <injury>" per injury (treat_own_injury), "Pay doctor (N stones)" (visit_clinic, Medicine.clinic_cost). Add one clinic place to qingshi_village and fallen_star_market in regions.json. |
| QA-002 | qa | todo | End-to-end life script test (tests/unit/test_full_life.gd): drive one character through GameState only: create, cultivate to Qi Refining 3, join a sect, work a profession, refine a pill, buy/equip gear, fight + respawn via the artifact, court + propose + marry an eligible NPC, try for a child until born, save, load, and assert state survives the round trip. Fix any bug you find (small) or file a task. |

## P1: Core gameplay loops
| id | role | status | task |
|---|---|---|---|
| W-004d | world-ui | todo | Encounter choice window: on EventBus.encounter_choice_requested show the encounter text and GameState.encounter_choices() (disabled entries show their reason), call GameState.choose_encounter(index), close on encounter_choice_resolved. Can reuse ChoiceMenu with a small source object. Gamepad focus. |
| W-004e | content | todo | Convert split moral encounters into choice encounters (e.g. the wounded traveller: help / rob / walk away) with set_flag follow-ups (`requires_flag`: the grateful traveller returns, the robbed one's kin seek revenge). Only after W-004d lands, so choices are visible in-game. Depends on W-004d. |
| G-008b | world-ui | todo | Mission board in the sect hall: list Sects.available_missions for the player's sect with kind, days, required items (have/need), enemy danger (Combat.danger_label), contribution/rewards and cooldown (Sects.mission_cooldown_left); disabled entries show Sects.check_mission reasons; "Take mission" calls GameState.take_mission. Gamepad-friendly. |
| G-008c | systems | todo | Sect contribution shop: sects.json per-sect `shop` [{item_id, contribution, min_rank}] (technique manuals, pills, recipe scrolls), Sects.shop_items/check_purchase, GameState.buy_with_contribution(item_id); spending contribution never demotes (track spent separately from earned). Plus a sect-hall menu entry listing the shop (small UI, or split to world-ui if large). |
| G-008d | content | todo | Sect missions and shops content: 6+ missions per sect in data/sect_missions.json fitting each sect's alignment (Azure Cloud righteous patrols, Blood Lotus raids/sacrifices, Myriad Treasure Pavilion trade runs), and each sect's contribution shop stock. Depends on G-008 (schema) and G-008c. |
| ART-002 | systems | todo | Artifact functions framework: `data/artifact.json` "functions" list with unlock conditions (realm, artifact energy, flags) and effects. GameState.feed_artifact(item_id) converts spirit stones/treasures into artifact energy. Implement the first function: **Storage space** (separate item storage that is never dropped on death). |
| ART-005 | world-ui | todo | Artifact UI: an artifact screen (functions, locked/unlocked with conditions, energy, anchors list with bind/unbind), a respawn screen on death ("The artifact pulls your soul back...", choose an anchor), and anchor markers in the world. Gamepad friendly. Build incrementally: anchors + respawn screen now, functions once ART-002 lands. |
| G-010 | systems | todo | Cave abode: the player can claim a dwelling in a region (data/regions.json `abode` place with a claim cost), store items there, cultivate in seclusion (density bonus), auto-bind it as an artifact anchor slot candidate. CharacterData.abode (save-compatible). Pair with G-010b. |
| G-010b | world-ui | todo | Abode interactable: claim, storage chest (move items in/out), seclusion cultivation. Depends on G-010. |
| G-006 | systems | todo | Arrays: Array Master profession recipes that produce array flags/discs; placing an array at your abode (or later clan estate) boosts qi density there (data-driven `array` block in items.json). Depends on G-010. |
| G-009b | world-ui | todo | Show sect reputation (Reputation.describe: tier name + value per sect) on the character sheet, and the reputation price change at faction merchants (merchant `faction`, e.g. "(Honored price)" next to the buy label when Reputation.price_multiplier != 1). Depends on G-009 (done). |
| G-009c | content | todo | Reputation content: mark public moral encounter choices `"witnessed": true` (encounters.json effects), give sect missions explicit `reputation` rewards where fitting (e.g. raids hurt Azure Cloud reputation), and add a Blood Lotus-affiliated merchant (`faction`) in a demonic-leaning place. Depends on G-009 (done). |
| G-007c | systems | todo | Doctors heal NPC injuries (alignment + favor). NPCs need injuries first: let Npcs.simulate occasionally injure NPCs (data-driven chance), GameState.treat_npc(npc_id). |
| LIFE-001f | systems | todo | Evil artifacts can be bought: merchants that only sell to demonic players (e.g. `min_alignment`/`max_alignment` on a merchant place, or a `hidden_tags` list so `equipment` merchants skip `demonic` items), then give the three `lifespan_drain` items prices and a Night Market stock rule. Optionally an alignment hit the first time an evil artifact is equipped. |
| G-005c | content | todo | Talisman content: a talisman stall (`stock_tags: ["talisman"]`) in the market town, higher-rank talisman recipes taught by scrolls (learn_recipe), talismans as encounter loot, and buff talismans for higher realms. |
| F-005c | qa | todo | Extend the balance sim's "sensible cultivator" with real-play help (moving to higher-density spots/regions as realms allow, breakthrough pills bought with profession income, sect density bonus) and re-check late-realm (Void Refinement+) old-age deaths and whether progression is now too fast for heavenly-root characters. |

## P1b: Family & Clan (owner priority, see DESIGN.md "Family & Clan system")
| id | role | status | task |
|---|---|---|---|
| FAM-003b | systems | todo | Adoption: GameState.adopt(npc_id) for an orphaned/unrelated child NPC (or a generated foundling at an orphanage/temple), links parents/children with birth_rank "" (adopted), favor/alignment rules in data/family.json; lets female players and couples without a carrier grow a family. |
| FAM-004 | systems | todo | Training descendants: monthly training assignment for each child/disciple (cultivate, profession, study technique), teaching techniques the player knows, spending pills/stones on them; progress reported in the message log. CharacterData.training (save-compatible), Npcs.simulate honors it. |
| FAM-005 | systems | todo | Found a clan: requirements in data/family.json `clan` (default: Foundation Establishment, spirit stones, a claimed estate place). Player becomes Patriarch/Matriarch; clan has a name (player surname), members (family, spouses, recruited retainers), ranks (Patriarch, Elder, Core, Outer), treasury, reputation. New ClanData (src/core) saved in GameState.to_save_dict. GameState.found_clan / recruit / promote / deposit. |
| FAM-005b | world-ui | todo | Surface clan founding: a "Found the <Surname> Clan" option at an estate/abode place with Clans.check_found reasons, and a first version of the clan screen (members, ranks, treasury, promote/recruit). Depends on FAM-005. Grows into FAM-010. |
| FAM-006 | systems | todo | Clan estate: buildings in data/clan_buildings.json (ancestral hall, spirit field, alchemy room, protective array, library) with costs, build time and monthly effects (income, qi density, herb yield, training speed). Depends on FAM-005. |
| FAM-006b | world-ui | todo | Estate view: list buildings with build/upgrade actions and monthly effects (clan screen tab), and draw built buildings as placeholder shapes at the estate place. Depends on FAM-006. |
| FAM-003d | systems | todo | NPC couples (married generated NPCs, e.g. eligible NPCs who marry each other off-screen) have children during Npcs.simulate using Children.try_conceive/give_birth, with a population cap in data/family.json. Feeds FAM-013. |
| FAM-007 | systems | todo | Bloodlines: rare inheritable bloodline traits (data/bloodlines.json, e.g. Azure Dragon, Vermilion Phoenix) that can awaken at a realm and grant bonuses; inheritance odds through generations. |
| FAM-008 | systems | todo | Clan succession for NPC clans and heir designation: the Patriarch designates an heir (default: eldest child of the main wife); used by NPC clans when their patriarch dies and by the player's clan for an appointed Young Master/Mistress title. (The player does NOT permadie; see ART-001.) Depends on FAM-005. |
| FAM-009 | systems | todo | NPC clans (data/clans.json) with their own families; marriage alliances between clans; clan feuds and favor. Family members can join sects (clan + sect dual membership). Depends on FAM-005. |
| FAM-010 | world-ui | todo | Family tree & clan screen (HUD modal, gamepad-friendly): spouses, children with realm/age/roots, clan members, ranks, treasury, estate buildings; actions to assign training (FAM-004). Build incrementally on FAM-005b. |
| FAM-011 | world-ui | todo | Family home place type in regions where family members live (spouses/children appear there as NPCs); adoption entry at a temple/orphanage once FAM-003b lands. |
| FAM-012 | content | todo | Family content: names.json lists (100+ surnames, 200+ given names), eligible-NPC templates per region, data/family.json tuning, bloodline definitions and clan building definitions (once those systems exist). |
| FAM-013 | qa | todo | Generational sim: simulate 300 years with families headless; check population doesn't explode (cap/fertility tuning), save size stays reasonable, descendants' power curve is fun. Depends on FAM-003d. |

## P1c: The Creation Artifact (owner priority, see DESIGN.md "The Creation Artifact")
ART-001/ART-001b are done; ART-002 and ART-005 are in P1 above.

| id | role | status | task |
|---|---|---|---|
| ART-003 | systems | todo | Artifact function: **Appraisal** (reveals NPC roots/realm/talent and item grades in the UI via a query API) and **Inner world** (cultivate inside with high qi density and time dilation: N world days pass per M inner days). Depends on ART-002. |
| ART-004 | systems | todo | Artifact function: **Spirit garden** inside the inner world; plant herbs (G-003 herbs) that grow at accelerated speed and can be harvested. Depends on ART-003. |
| ART-006 | content | todo | Artifact lore and intro: an opening event at character creation where the mortal finds the artifact (dialogue file), artifact flavor text per function, and anchor-capable places across existing regions. Keep the artifact's maker/origin vague (owner has not decided it). |

## P2: Cultivation depth (roadmap item 4)
| id | role | status | task |
|---|---|---|---|
| CM-001 | systems | todo | Cultivation methods: techniques.json `kind: "method"` with element affinity, qi rate multiplier, max realm and passive effects; one active main method (CharacterData.main_method, save-compatible) that multiplies Cultivation qi gain (bonus when it matches your root element). GameState.set_main_method. Starter method for everyone so old saves keep their speed. |
| CM-001b | world-ui | todo | Techniques screen: show methods separately, mark the main method, "Set as main method" action with the qi rate / affinity shown. Depends on CM-001. |
| CM-001c | content | todo | Method content: 8+ methods across elements and alignments (righteous sect methods sold in contribution shops, demonic blood methods, rare ruins inheritances), with higher-realm caps so players must find better ones. Depends on CM-001. |
| TRIB-001 | systems | todo | Heavenly Tribulations: data/realms.json `tribulation` block on major breakthroughs (Core Formation and up by default): N lightning waves with damage scaled by realm; survive via HP/defense, talismans, pills, arrays; failure injures, and the last wave can kill via GameState._die_violently (artifact respawn). Demonic alignment adds an extra heart-demon wave. See DESIGN.md open question for defaults. |
| TRIB-001b | world-ui | todo | Tribulation sequence: a banner/screen showing each wave, damage taken and survival, plus a "prepare" warning before attempting a breakthrough that triggers a tribulation. Depends on TRIB-001. |
| DAO-001 | systems | todo | Dao insights: data/dao.json insights (Sword Dao, Fire Dao, Dao of Life…) gained by rare encounters, practicing techniques long enough, or seclusion with a Comprehension check; each insight level boosts related techniques and breakthrough odds. CharacterData.dao (save-compatible). |
| C-003 | content | todo | Techniques expansion: 10+ combat techniques across elements/alignments with manuals as merchant stock, sect shop items or encounter loot (follow data/techniques.json `_doc`). |

## P3: World
| id | role | status | task |
|---|---|---|---|
| C-001 | content | todo | Generic dialogue for generated NPCs: data/dialogue/generic_cultivator.json (greet, chat, small gift, ask about the region) with favor gains, so courtship candidates have something to say. If Dialogue only resolves files by def id, add a small `generic` fallback in GameState._npc_dialogue with a test. Depends on W-003 (done). |
| C-002 | content | todo | Enemies expansion: data/enemies.json has 9 enemies; add 10+ for Foundation and Core Formation (beasts with ore/herb loot, rogue and demonic cultivators), and use them in encounters.json realm-gated entries. |
| C-005 | content | todo | A fifth region (e.g. a marsh or ruined city with a demonic lean): regions.json places (meditation, gather, explore, merchant), routes with realm gates, gather tables, 8+ encounters tagged for it. Pure data; follow regions.json `_doc`. |
| C-006 | content | todo | 3 new named NPCs (data/npcs.json) with dialogue files in data/dialogue/, spread across regions (e.g. a wandering alchemist, a blood lotus disciple, a retired elder) with favor-gated rewards. |
| RIV-001 | systems | todo | Rivals and grudges: CharacterData.grudges/gratitude per NPC (save-compatible); killing/robbing/humiliating creates grudges with the victim's family/sect; a named rival NPC grows alongside the player and appears in encounters; Npcs.simulate lets enemies hunt you. |
| W-005 | systems | todo | Secret realms (first pass): data/secret_realms.json (opens every N years for M days, realm caps, floors of encounters with treasures and guardians), GameState.enter_secret_realm. Pair with a world-ui entry point later. |

## P4: QA and tooling
| id | role | status | task |
|---|---|---|---|
| QA-003 | qa | todo | Save compatibility fixtures: commit tests/fixtures/saves/ with a save from the oldest supported SAVE_VERSION and one from the current version (hand-written JSON), and a test that both load via SaveManager/GameState with sane defaults for every newer field. Document "add a fixture when bumping SAVE_VERSION" in CLAUDE.md. |
| QA-004 | qa | todo | Obtainability audit test: every item in items.json is reachable (merchant stock tags, recipe output, encounter/deed/enemy loot, dialogue reward or starting item) and every recipe scroll is obtainable; known exceptions listed in an explicit allowlist with a task id (e.g. Blood-Drinker Saber → LIFE-001e). |
| QA-005 | qa | todo | Family edge cases: spouse dies while pregnant, carrier spouse divorces/dies mid-pregnancy, save/load mid-pregnancy, child of a deceased parent, player respawn during pregnancy. Add tests, fix small bugs, file tasks for big ones. |
| QA-006 | qa | todo | Economy sim (tests/sim/simulate_economy.gd): spirit stone income (professions, sales, missions once G-008 lands) vs costs (pills, gear, artifact recharge growth) across a 200-year life; report whether the player can afford breakthroughs and recharges, and propose data tweaks. |
| QA-007 | qa | todo | Combat balance sim: per realm, a typical player (realm, gear, techniques, talismans) vs every enemy in enemies.json; report win rates and flag enemies that are trivial or unbeatable for the realm they appear at in encounters.json. |
| QA-008 | qa | todo | Gamepad/focus audit: a scene test that opens each HUD screen (inventory, techniques, character sheet, crafting, pause, load, settings, combat report) and asserts something has focus and ui_cancel closes it. Fix screens that fail. |
| QA-009 | qa | todo | Review recently merged code (G-005b combat talismans, FAM-003 children, FAM-002c eligible NPCs) for correctness and missing tests; fix small bugs, file tasks for larger ones. |
| UI-LEAK-001 | world-ui | todo | Most HUD screens call `UIStyle.panel().get_theme_stylebox("panel")` in _init and leak the temporary PanelContainer (shows as "ObjectDB instances leaked" when screens are built in tests). Add a `UIStyle.panel_style()` helper returning just the StyleBox and use it everywhere (character_sheet already frees its temp panel). |

## Local sessions
The local sessions that built combat/techniques, world/exploration/NPCs/dialogue and the UI screens have finished (2026-10-02); their work is on main and these areas are open to anyone. Add follow-up tasks above.

## Done
| id | task |
|---|---|
| G-009 | Sect reputation: Reputation system, CharacterData.reputation, witnessed deeds move reputation per sect deed_scale, min_join gating, faction merchant price tiers, mission and leave-sect reputation. |
| G-004c | Higher-grade equipment: Profound Iron / Dragon-Blood Gold ores, 4 new forge recipes with manuals, Heavenforge Smithy in Fallen Star Market, equipment encounters. |
| LIFE-001e | Evil artifacts obtainable: Blood-Drinker Saber (wild), Corpse-Silk Burial Armor and Myriad Souls Banner (ruins), once per life, each with a righteous destroy alternative. |
| FAM-002f | Generated NPCs placed in the world: regions.json `npc_spots`, Npcs.generated_in_region/spot_positions/world_title/describe, gender colors, "Look" option. |
| FAM-002e | Dual cultivation entries at meditation spots for living spouses in the region (Family.spouses_in_region), with bonus % and disabled reasons. |
| FAM-001b | Family on the character sheet: Family.describe_links (spouses with rank, children, parents, deceased), gender/family header, one-time gender picker (GameState.choose_gender). |
| W-004c | Encounter choices: encounters.json `choices` and `requires_flag`, Exploration.check_choice/choices/resolve_choice, GameState.encounter_choices/choose_encounter. |
| G-008 | Sect missions part 1: data/sect_missions.json, Sects.available_missions/check_mission/complete_mission, CharacterData.mission_cooldowns, GameState.take_mission. |
| FAM-002g | Widowed spouses: dead spouses stay in family history but free their rank slot (Family.living_spouses/is_living, `people` param); widowed NPCs can remarry. |
| G-002g | Crafting screen polish: x5 batch crafting (GameState.refine_batch), carried recipe scrolls listed with a Study button (Alchemy.scroll_recipes). |
| G-005b | Combat talismans: strike/shield/escape talismans readied for fights (CombatTalismans), GameState.ready_talisman/unready_talisman. |
| FAM-003 | Children part 1: conception, per-carrier pregnancy, birth with inherited roots/attributes, birth_rank, GameState.try_for_child. |
| LIFE-001d | 3 more forbidden secret arts (Blood Shadow Flight, Ten-Thousand Bones Armor, Heaven-Devouring Burst) with manuals and righteous sealing alternatives. |
| FAM-002c | Eligible generated NPCs per region (Npcs.ensure_eligible), proud flag. |
| FAM-002b | Dual cultivation (Family.dual_multiplier, GameState.dual_cultivate), spouse favor over time. |
| QA-20261003-1 | Evil-weapon drain in fight_enemy fixed for violent death; integration tests. Widowed-spouse observation → FAM-002g. |
| G-002b | Generic CraftingScreen for alchemy/forge/talismans from the workshop. |
| G-005 | Talismans part 1: inscribing, `buff` effect key, Blank Talisman Paper, 4 buff talismans. |
| F-005b | Lifespan balance: realms.json tuning, Cultivation.expected_realm_years, lifespan-gain data rule. |
| G-002f | Core Forming recipe scroll as Foundation+ ruins loot (3 alignment variants). |
| FAM-002 | Courtship and marriage core (data/family.json, Family, GameState.court/propose). |
| LIFE-001c | Evil artifact weapons: `lifespan_drain` equip key, Blood-Drinker Saber (not yet obtainable → LIFE-001e). |
| ART-001b | Artifact lives/anchors/recharge on the character sheet. |
| F-005 | Balance sim script tests/sim/simulate_life.gd. |
| G-004 | Blacksmithing core: Equipment, weapon/armor slots, 4 forge recipes. |
| FAM-001 | Character identity (gender, names, family links) and generated NPCs (Names, Npcs.spawn). |
| G-002d | 6 more alchemy recipes and pills with scrolls. |
| LIFE-001b | Temporary combat buffs (Buffs) and the Blood Demon Rage secret art. |
| G-002e | Pill quality: great successes yield higher-grade pills. |
| G-002c | Recipe learning from scrolls (learn_recipe effect). |
| G-002 | Alchemy crafting core (data/recipes.json, Alchemy, GameState.refine). |
| LIFE-001 | Lifespan as a resource: burn/extend lifespan, effect keys, Blood Essence Burning Pill, Longevity Pill. |
| ART-001 | Creation Artifact respawn core: lives, anchors, recharge, GameState._die_violently. |
| G-001b | Injuries on the character sheet and a HUD indicator. |
| G-001 | Injuries from breakthroughs and defeats (data/injuries.json, Injuries). |
| G-007 | Doctor/Medicine core: treat own injuries, clinic, treat patients (UI → G-007b). |
| W-004b | 22 more encounters (now 42+): alignment fortunes, realm-gated foes, NPC cameos. |
| F-001 | GameState integration tests for sect, shop, items, professions. |
| F-002 | Pause menu on Esc. |
| F-003 | Breakthrough banner feedback. |
| F-004 | Multiple save slots with metadata. |
| F-004b | Load screen in main menu and pause menu. |
| F-006 | Settings: window mode, UI scale, volume buses. |
| G-003 | Herbs/ores (12 items, tags herb/ore), gather place type + gathering spots, Herb & Ore Stall that buys back at half price. |
| W-001 | Regions and travel: 4 data-driven regions (data/regions.json), world scene built per region, routes with days and realm gates (Exploration). |
| W-004 | Random encounters (data/encounters.json): tags, realm gates, Fortune-weighted, deadly lethal foes are evaded, combat via GameState.fight. |
| W-002 | NPC model: 5 named NPCs (data/npcs.json) age, cultivate monthly, break through and die; saved in GameState.npcs with per-NPC favor. |
| W-003 | Dialogue rules + data (src/core/systems/dialogue.gd, data/dialogue/*.json): entry conditions, hidden/locked choices, effects, favor, time. Inline choice-menu fallback. |
| F-000 | Project foundation: data-driven core systems, autoloads, village slice, save/load, tests, tooling. |
