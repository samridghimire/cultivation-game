# Game Design

> Living document. The human owner makes final design calls; agents add questions at the bottom instead of inventing big features.

## Vision (from the owner)
A **fully fleshed-out cultivation game where the possibilities feel endless, like a cultivation light novel.**
Any story a xianxia protagonist might live should be playable: the trash-root orphan who rises through grit, the sect genius,
the demonic cultivator who devours others, the lone rogue hunting inheritances, the **patriarch who founds a clan that lasts for
generations**. Build the foundation first, then widen the world one solid system at a time.

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
6. **Family and legacy.** You can marry, have children, train your descendants, and found a clan as its Patriarch or Matriarch. Family and sect are not exclusive: you can do either, both, or neither.

## Family & Clan system (owner priority)
The player may start a family and/or join a sect.
- **Courtship and marriage.** Build favor with NPCs and marry a Dao companion. Spouses are full characters who cultivate, age and can die. Dual cultivation gives both partners a bonus.
- **Children.** Children inherit spiritual roots and attributes from both parents, with random variation (a two-trash-root couple can still produce a genius, rarely). They grow up over in-game years, and adoption is also possible.
- **Training descendants.** Teach children techniques you know, assign training (cultivation, professions), pay for pills and resources, and send them to join sects.
- **Founding a clan.** At sufficient strength (e.g. Foundation Establishment plus resources) found a clan with your surname and become its **Patriarch/Matriarch**. A clan has members (blood family, spouses, retainers), ranks (Patriarch, Elders, core members, outer members), a treasury, an estate with buildings (ancestral hall, spirit fields, alchemy room, protective array) and reputation.
- **Generations.** Descendants marry and have children of their own. Bloodlines can carry special traits that awaken. Your clan can rise to rival sects, form marriage alliances, or wage feuds with NPC clans.
- **Legacy (proposed default, owner to confirm).** When you die, you may continue playing as an heir, and the clan persists. With no heir, the run ends.

## Long-term roadmap (big systems, in rough order after the foundation)
1. Crafting loops: alchemy, blacksmithing, talismans, arrays (G-00x)
2. **Family & clan** (FAM-xxx)
3. Sect life: missions, contribution shop, sect ranks with real duties, rising to Sect Master or **founding your own sect**
4. Cultivation methods (main technique that sets qi rate, element and special effects), Dao insights / comprehension, **Heavenly Tribulations** at major breakthroughs
5. Rivals and karma: named rivals, grudges and vendettas, enemies hunting you, debts of gratitude
6. Secret realms, inheritance grounds, ancient ruins, auctions
7. Spirit beasts and companions, body cultivation path, demonic arts tree
8. Living world: NPC clans and sects that grow, ally and wage war; beast tides; world events
9. Endgame: Ascension to the Immortal Realm

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
| Injuries (from breakthroughs and combat) | ✅ | `data/injuries.json`, `Injuries` |
| Combat and cultivation techniques | 🚧 | `Combat`, `Techniques`, `data/enemies.json`, `data/techniques.json` |
| Inventory and techniques screens | 🚧 | `src/ui/` |
| Top-down world with interactables | ✅ placeholder art | `src/world/` |

## Realm ladder
Mortal → Qi Refining (9 layers) → Foundation Establishment → Core Formation → Nascent Soul → Soul Formation →
Void Refinement → Body Integration → Mahayana → Tribulation Transcendence. Post-Qi-Refining realms have Early/Middle/Late/Peak stages.

## Open design questions (for the human)
- Family: should the player pick a gender at creation, and who can have children (any couple, or with adoption as the alternative)? Proposed default: player chooses gender, any couple may marry, birth for opposite-sex couples and adoption for anyone, polygamy off by default.
- Legacy: confirm "continue as heir on death".
- Permadeath, or reincarnation / legacy system on death?
- Real-time world (NPCs move, time flows) or turn-like time that only passes through actions (current)?
- Combat style: turn-based, real-time action, or auto-resolved with techniques/strategy?
- Art direction: pixel art? ink-wash painterly? (affects asset pipeline)
- Should evil paths include demonic cultivation techniques (blood refining, soul devouring) as a separate progression tree?
