# Game Design

> Living document. The human owner makes final design calls; agents add questions at the bottom instead of inventing big features.

## Pitch
An open-ended **xianxia cultivation life sim / RPG**. You begin as a 16-year-old mortal with a randomly rolled spiritual root.
You can cultivate toward immortality, join a sect or stay a rogue cultivator, master professions, and walk a righteous, neutral or demonic path.
Your lifespan is limited, and breaking through to a higher realm is how you extend it.

## Pillars
1. **Total freedom of path.** Righteous, demonic and rogue playthroughs are equally supported. Evil acts are real options with real consequences (reputation, sect access, enemies).
2. **Cultivation is the spine.** Realm progression, bottlenecks, risky breakthroughs, and lifespan pressure drive every decision.
3. **Professions matter.** Alchemists, Blacksmiths, Talisman Masters, Array Masters, Doctors, Beast Tamers each have distinct crafting loops that feed cultivation, combat and economy.
4. **A living world.** NPCs cultivate, age, form grudges and die. Sects rise and war. (Long-term goal.)
5. **Systems over scripts.** Content is data-driven so the world can grow quickly.

## Current systems (foundation)
| System | Status | Where |
|---|---|---|
| Realms & stages (Mortal → Tribulation Transcendence) | ✅ | `data/realms.json`, `Cultivation` |
| Spiritual roots (5 elements, grades, purity) | ✅ | `data/spiritual_roots.json`, `SpiritualRoots` |
| Attributes (Constitution, Comprehension, Spirit, Fortune, Charisma) | ✅ | `data/attributes.json` |
| Breakthroughs with risk, pills that boost odds | ✅ | `Cultivation.attempt_breakthrough` |
| Lifespan & death by old age | ✅ | `GameState._on_days_advanced` |
| Alignment (Demonic … Righteous) and deeds | ✅ | `data/alignment.json`, `data/deeds.json` |
| Sects (join/leave, requirements, ranks, contribution) | ✅ | `data/sects.json`, `Sects` |
| Professions (ranks, XP, income) | ✅ basic | `data/professions.json`, `Professions` |
| Items, merchant, using pills | ✅ basic | `data/items.json`, `Items` |
| Save/load | ✅ | `SaveManager` |
| Data-driven regions, travel, exploration encounters | 🚧 | `data/regions.json`, `data/encounters.json`, `Exploration` |
| Combat and cultivation techniques | 🚧 | `Combat`, `Techniques`, `data/enemies.json`, `data/techniques.json` |
| Inventory and techniques screens | 🚧 | `src/ui/` |
| Top-down world with interactables | ✅ placeholder art | `src/world/` |

## Realm ladder
Mortal → Qi Refining (9 layers) → Foundation Establishment → Core Formation → Nascent Soul → Soul Formation →
Void Refinement → Body Integration → Mahayana → Tribulation Transcendence. Post-Qi-Refining realms have Early/Middle/Late/Peak stages.

## Open design questions (for the human)
- Permadeath, or reincarnation / legacy system on death?
- Real-time world (NPCs move, time flows) or turn-like time that only passes through actions (current)?
- Combat style: turn-based, real-time action, or auto-resolved with techniques/strategy?
- Art direction: pixel art? ink-wash painterly? (affects asset pipeline)
- Should evil paths include demonic cultivation techniques (blood refining, soul devouring) as a separate progression tree?
