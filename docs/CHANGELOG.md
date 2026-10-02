# Changelog

One line per merged change, newest first: `YYYY-MM-DD [task-id] summary`.

- 2026-10-02 [F-005] Balance sim `tests/sim/simulate_life.gd` (N lives headless, avg age per realm, old-age deaths per realm); filed F-005b with findings.
- 2026-10-02 [G-002d] 6 new alchemy recipes and pills (healing, qi, righteous Clear Heart, demonic Blood Demon, Core Forming) with recipe scrolls.
- 2026-10-02 [LIFE-001b] Temporary combat buffs (Buffs, CharacterData.buffs, applied in Combat.stats) and the forbidden Blood Demon Rage art (technique `activation`: burns 10 years for +80% attack/+30% speed for a month), GameState.activate_technique, Activate button with lifespan cost on the techniques screen, manual from a one-time ruins encounter.
- 2026-10-02 [G-002e] Pill quality: recipes' optional great_output, Alchemy.great_chance (from the margin of success chance over great_threshold), Superior Qi Gathering Pill and Flawless Foundation Establishment Pill; other recipes yield double on a great success.
- 2026-10-02 [F-004b] Load screen listing all save slots (name, realm, date, age) with confirm-to-delete; used by the main menu (Load Game, Continue = newest save) and the pause menu.
- 2026-10-02 [LIFE-001] Lifespan as a resource: burned/bonus years, burn_lifespan/extend_lifespan effects, Blood Essence Burning Pill, Longevity Pill (ruins), lifespan-cost warnings.
- 2026-10-02 [G-002c] Recipe learning: starter recipes plus recipe scrolls (learn_recipe effect, 3 scrolls), CharacterData.known_recipes, old saves keep rank-unlocked recipes.
- 2026-10-02 [F-001] GameState integration tests for join_sect, leave_sect, buy_item, use_item, work_profession (contribution, promotion, rogue). No bugs found.
- 2026-10-02 [W-004b] 22 new encounters (42 total): moral fortunes for righteous/demonic players, realm-gated foes, NPC cameos.
- 2026-10-02 [ART-001] Creation Artifact respawn core: lives, anchors (anchor_id places), recharging with spirit stones, lethal defeats respawn the player (CreationArtifact, data/artifact.json).
- 2026-10-02 [G-002] Alchemy: data/recipes.json, Alchemy system (rank/Comprehension success chance, failure burns herbs), GameState.refine, refine options at the workshop.
- 2026-10-02 [W-002/W-003/G-003] Living NPCs (Npcs), branching dialogue (Dialogue, data/dialogue/), herbs/ores with gathering spots and a buy-back stall.
- 2026-10-02 [G-007] Doctor: self-treatment, paid clinic and treating patients (Medicine).
- 2026-10-02 [G-001b] Injury UI: HUD injury line, Injuries section on the character sheet, healing items described and Use disabled when nothing to heal.
- 2026-10-02 [F-006] Settings: fullscreen, UI scale, Master/Music/SFX volume in user://settings.cfg (src/autoload/settings.gd, src/ui/settings_screen.gd); opened from the main menu and the pause menu.
- 2026-10-02 [G-001] Injuries: breakthrough failures and combat defeats can injure; healing over time and with salves/pills.
- 2026-10-02 [F-004] Save slots backend: per-save metadata, list_slots, delete_save, slot-name validation (SaveManager).
- 2026-10-02 [F-003] Breakthrough banner + screen flash (src/ui/banner.gd).
- 2026-10-02 [F-002] Pause menu: Resume / Save / Load / Settings stub / Save & Quit (src/ui/pause_menu.gd).
- 2026-10-02 [F-000] Project foundation: Godot 4.7 project, data-driven realms/roots/sects/professions/items/deeds, GameState/EventBus/GameClock/SaveManager, village slice, 78 tests, tools/test.sh.
