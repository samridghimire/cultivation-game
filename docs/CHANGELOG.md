# Changelog

One line per merged change, newest first: `YYYY-MM-DD [task-id] summary`.

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
