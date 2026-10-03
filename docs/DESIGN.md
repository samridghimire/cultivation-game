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
- **Wives and concubines (owner decision).** A male character can take one main wife plus **multiple concubines**, as in the genre. **A female character has a single Dao companion** (plus adoption). Spousal rank (main wife vs concubine) matters for status, inheritance of clan leadership and household politics. Limits and rules live in `data/family.json` per gender, not hardcoded.
- **Children.** Children inherit spiritual roots and attributes from both parents, with random variation (a two-trash-root couple can still produce a genius, rarely). **Several partners can be pregnant at the same time.** Children grow up over in-game years, and adoption is also possible. Children of the main wife vs concubines can differ in status (heir priority), which the player can override as Patriarch.
- **Training descendants.** Teach children techniques you know, assign training (cultivation, professions), pay for pills and resources, and send them to join sects.
- **Founding a clan.** At sufficient strength (e.g. Foundation Establishment plus resources) found a clan with your surname and become its **Patriarch/Matriarch**. A clan has members (blood family, spouses, retainers), ranks (Patriarch, Elders, core members, outer members), a treasury, an estate with buildings (ancestral hall, spirit fields, alchemy room, protective array) and reputation.
- **Generations.** Descendants marry and have children of their own. Bloodlines can carry special traits that awaken. Your clan can rise to rival sects, form marriage alliances, or wage feuds with NPC clans.
- Your descendants are your legacy and power base, but the run follows **you**; see the Creation Artifact below.

## The Creation Artifact (the protagonist's "golden finger")
Every great cultivation protagonist has something that sets them apart. Ours is a mysterious **Creation Artifact** bound to the player's soul at the start of the game.
- **Respawn instead of permadeath.** When the player is killed, the artifact pulls their soul back and they **respawn at one of their bound anchor locations**.
- **Lives (owner decision).** Each respawn consumes one of the artifact's stored **lives**. The player **recharges the artifact with spirit stones to add more lives** (cost scales up, tunable in `data/artifact.json`). With no lives left, death is final. Smaller costs on respawn (some qi lost, some time passes) remain tunable in data.
- **Anchors.** The player binds anchors at specific places (e.g. a meditation spot, their cave abode, clan estate). Anchor slots are limited and **more unlock as the player's cultivation realm rises**. Choosing where to respawn is a strategic decision.
- **Unlockable functions.** The artifact has many sealed functions that unlock as the player advances (realm milestones, feeding it treasures/spirit stones, story events). Candidate functions, all data-driven in `data/artifact.json`:
  - Respawn + anchors (available from the start, 1 anchor)
  - Storage space (a personal pocket dimension for items)
  - Appraisal (see hidden stats: NPC talent/realm, item grade, herb age)
  - Inner world (a pocket realm with dense qi and time dilation for cultivation)
  - Spirit garden (grow herbs inside the inner world at accelerated speed)
  - Further secrets for late game (owner to expand)
- The artifact is the main story hook: who made it, why it chose the player, and who else wants it.

## Long-term roadmap (big systems, in rough order after the foundation)
1. Crafting loops: alchemy, blacksmithing, talismans, arrays (G-00x)
2. **Family & clan** (FAM-xxx) and the **Creation Artifact** (ART-xxx)
3. Sect life: missions, contribution shop, sect ranks with real duties, rising to Sect Master or **founding your own sect**
4. Cultivation methods (main technique that sets qi rate, element and special effects), Dao insights / comprehension, **Heavenly Tribulations** at major breakthroughs
5. Rivals and karma: named rivals, grudges and vendettas, enemies hunting you, debts of gratitude
6. Secret realms, inheritance grounds, ancient ruins, auctions
7. Spirit beasts and companions, body cultivation path, demonic arts tree
8. Living world: NPC clans and sects that grow, ally and wage war; beast tides; world events
9. Endgame: Ascension to the Immortal Realm

## Current systems (foundation)
"Core" = rules + tests exist in GameState; "UI" = reachable by the player in-game. Updated 2026-10-03 12:00 UTC (32 PRs open).
| System | Status | Where |
|---|---|---|
| Realms & stages (Mortal → Tribulation Transcendence) | ✅ | `data/realms.json`, `Cultivation` |
| Spiritual roots (5 elements, grades, purity) | ✅ | `data/spiritual_roots.json`, `SpiritualRoots` |
| Attributes (Constitution, Comprehension, Spirit, Fortune, Charisma) | ✅ | `data/attributes.json` |
| Breakthroughs with risk, pills that boost odds | ✅ | `Cultivation.attempt_breakthrough` |
| Lifespan, death by old age, burning/extending lifespan | ✅ | `Cultivation`, `GameState._on_days_advanced` |
| Alignment (Demonic … Righteous) and deeds | ✅ | `data/alignment.json`, `data/deeds.json` |
| Sects (join/leave, requirements, ranks, contribution, missions) | ✅ core, 🚧 mission board (G-008b) and contribution shop (G-008c) in PR; rank duties G-008e | `data/sects.json`, `data/sect_missions.json`, `Sects` |
| Professions (ranks, XP, income) | ✅ basic | `data/professions.json`, `Professions` |
| Alchemy (recipes, scrolls, pill quality) + crafting screen | ✅ | `data/recipes.json`, `Alchemy`, `src/ui/crafting_screen.gd` |
| Blacksmithing and equipment (weapon/armor, 3 grades incl. Core Formation gear) | ✅ core, 🚧 equip UI in PR (G-004b) | `Equipment`, `data/recipes.json` |
| Talismans (buff talismans, combat strike/shield/escape) | ✅ core, 🚧 no ready UI (G-005d) | `Alchemy`, `Buffs`, `CombatTalismans` |
| Temporary buffs, forbidden secret arts, lifespan-draining evil artifacts | ✅ | `Buffs`, `data/techniques.json`, `data/items.json` |
| Medicine / Doctor (treat injuries, clinic, patients) | ✅ core, 🚧 clinic place in PR (G-007b) | `Medicine` |
| Items, merchants, using pills | ✅ basic | `data/items.json`, `Items` |
| Save/load, multiple slots | ✅ | `SaveManager` |
| Creation Artifact: lives, anchors, respawn, recharge | ✅ core + sheet UI; 🚧 functions/Storage (ART-002) and respawn screen (ART-005) in PR | `data/artifact.json`, `CreationArtifact` |
| Data-driven regions (4), travel, exploration encounters (61) with choices | ✅ core, 🚧 choice window in PR (W-004d) | `data/regions.json`, `data/encounters.json`, `Exploration` |
| Injuries (from breakthroughs and combat) | ✅ | `data/injuries.json`, `Injuries` |
| Combat (auto-resolved) and techniques | ✅ basic | `Combat`, `Techniques`, `data/enemies.json`, `data/techniques.json` |
| NPCs (named + generated), aging, monthly sim | ✅ | `data/npcs.json`, `Npcs`, `Names` |
| Dialogue | ✅ core, 🚧 dialogue window in PR (W-003b) | `Dialogue`, `data/dialogue/` |
| Family: identity, courtship, marriage, dual cultivation, children | ✅ core; ✅ UI: family on sheet, generated NPCs in world, dual cultivation; 🚧 court/propose, chat/gifts, try for child, adoption in PR | `data/family.json`, `Family`, `Children` |
| Clans, estates, bloodlines, training descendants | 🚧 FAM-005, FAM-007, FAM-004 in PR; estates FAM-006 | |
| Cultivation methods, Dao insights, Heavenly Tribulations | 🚧 CM-001 in PR, TRIB-001 claimed; ❌ DAO-001 | |
| Cave abode, arrays | 🚧 G-010 in PR; ❌ arrays (G-006) | |
| Rivals/karma, secret realms, inheritances, spirit beasts, auctions, world events | ❌ (RIV-001+, W-005+, BEAST-001, AUC-001, LW-001) | |
| Inventory, techniques, character sheet, settings, pause, load screens | ✅ | `src/ui/` |
| Top-down world with interactables | ✅ placeholder art | `src/world/` |

## Lifespan as a resource (owner decision)
- Breaking through to a higher realm adds lifespan, so a cultivator who keeps progressing should **rarely die of old age**. The Creation Artifact does **not** save the player from old age.
- Lifespan can be **spent**: forbidden secret arts, demonic weapons and evil cultivator artifacts that burn years of life for power. Recklessly burning lifespan is the main way a strong cultivator dies of old age.
- Lifespan can also be extended (longevity pills, rare treasures, late-game artifact functions).

## Realm ladder
Mortal → Qi Refining (9 layers) → Foundation Establishment → Core Formation → Nascent Soul → Soul Formation →
Void Refinement → Body Integration → Mahayana → Tribulation Transcendence. Post-Qi-Refining realms have Early/Middle/Late/Peak stages.

## Open design questions (for the human)
- **Decided:** player picks gender at creation; a male character can have one main wife + multiple concubines and multiple simultaneous pregnancies.
- **Decided:** no permadeath for the player; the Creation Artifact respawns them at bound anchors, with more anchors and functions unlocking as they level up.
- **Decided:** a female player character has a single Dao companion plus adoption.
- **Decided:** respawns consume artifact lives, which are recharged with spirit stones; at zero lives death is final.
- **Decided:** the artifact does not prevent death by old age; realm breakthroughs add lifespan, and lifespan can be burned for power (forbidden arts, evil weapons).
- Permadeath, or reincarnation / legacy system on death?
- Real-time world (NPCs move, time flows) or turn-like time that only passes through actions (current)?
- Combat style: turn-based, real-time action, or auto-resolved with techniques/strategy?
- Art direction: pixel art? ink-wash painterly? (affects asset pipeline)
- Should evil paths include demonic cultivation techniques (blood refining, soul devouring) as a separate progression tree?
- (FAM-002) Smallest version implemented, tunable in `data/family.json`: courting is only between opposite genders, an NPC of a higher major realm (or flagged `proud`) refuses to be a concubine, proposals need favor 60, at most 1 major realm apart and alignment within 600. Should same-gender Dao companions be allowed, and are these thresholds right?
- (FAM-002g) **Widowed spouses.** Default the agents will build: a dead spouse stays in your family history but no longer takes up a wife/concubine/Dao companion slot, so you can remarry. Should there be a mourning period or an alignment/favor penalty for remarrying quickly?
- (TRIB-001) **Heavenly Tribulations.** Default: tribulations strike at every major-realm breakthrough from Core Formation upward, as several lightning waves you survive with HP, defense, talismans and pills. Failing injures you, and the last wave can kill you, in which case the Creation Artifact respawns you and spends a life. Demonic cultivators face an extra heart-demon wave. Is this right, and should a tribulation also hit at Foundation Establishment?
- (FAM-005) **Clan founding requirements.** Default: Foundation Establishment, 500 spirit stones and a claimed estate/abode, all in `data/family.json`. Can a rogue still in a sect found a clan, or must they leave or get permission?
- (W-005/G-008) **Founding your own sect** (roadmap item 3) is not scheduled yet. Default proposal: it unlocks at Nascent Soul, needs a mountain gate place, and reuses the clan treasury/buildings model. Should it be a separate system from clans, or a clan that grows into a sect?
- **Main story / Creation Artifact origin.** Agents keep the artifact's maker, why it chose the player and who hunts it vague until you decide. Do you want to outline the main story arc (acts, antagonist faction), or should agents propose 2-3 options for you to pick from?
- (G-008e) **Sect promotion.** Default: promotion to Inner Disciple and above needs a realm minimum plus a trial fight, ranks pay a monthly stipend, and missing the monthly duty only skips the stipend (no demotion). Should neglecting duties demote or expel a disciple?
- (BEAST-001) **Spirit beasts.** Default: only Beast Tamers can tame, one active companion fights alongside you, beasts grow by feeding. Should non-tamers be able to keep a beast (e.g. one bought or gifted), and how many companions at once?
- (DEM-001) **Devouring.** Default: after defeating a cultivator the player can devour their cultivation for qi at a big alignment cost and a heart-demon injury risk. This is the smallest demonic art; the separate demonic tree (DEM-002) stays blocked on the question above.
