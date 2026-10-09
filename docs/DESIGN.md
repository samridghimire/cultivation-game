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
"Core" = rules + tests exist in GameState; "UI" = reachable by the player in-game.
| System | Status | Where |
|---|---|---|
| Realms & stages (Mortal → Tribulation Transcendence) | ✅ | `data/realms.json`, `Cultivation` |
| Spiritual roots (5 elements, grades, purity) | ✅ | `data/spiritual_roots.json`, `SpiritualRoots` |
| Attributes (Constitution, Comprehension, Spirit, Fortune, Charisma) | ✅ | `data/attributes.json` |
| Breakthroughs with risk, pills that boost odds | ✅ | `Cultivation.attempt_breakthrough` |
| Lifespan, death by old age, burning/extending lifespan | ✅ | `Cultivation`, `GameState._on_days_advanced` |
| Alignment (Demonic … Righteous) and deeds (with cooldowns) | ✅ | `data/alignment.json`, `data/deeds.json` |
| Sects (join/leave, requirements, ranks with realm/stage gates, contribution, missions, trials/stipends/duties, monthly elder lecture) | ✅ (shop: G-008c; rank UI: G-011b; lecture at the sect hall) | `data/sects.json`, `Sects` |
| Sect reputation (witnessed deeds, join gating, faction prices) | ✅ (sheet + faction shop prices) | `data/sects.json`, `Reputation` |
| Professions (ranks, XP, income, monthly crafting commissions delivered at workshops) | ✅ basic + commissions (PROF-001) | `data/professions.json`, `Professions` |
| Alchemy (recipes, scrolls, pill quality) + crafting screen | ✅ | `data/recipes.json`, `Alchemy`, `src/ui/crafting_screen.gd` |
| Blacksmithing and equipment (weapon/armor) | ✅ (equip from inventory, unequip on the character sheet) | `Equipment`, `data/recipes.json` |
| Talismans (buff talismans, combat strike/shield/escape) | ✅ (ready/unready in the inventory) | `Alchemy`, `Buffs`, `CombatTalismans` |
| Temporary buffs and forbidden secret arts | ✅ | `Buffs`, `data/techniques.json` |
| Medicine / Doctor (treat injuries, clinic, patients) | ✅ (clinic places) | `Medicine` |
| Items, merchants (shop screen with Buy/Sell tabs), using pills | ✅ | `data/items.json`, `Items`, `src/ui/shop_screen.gd` |
| Save/load, multiple slots | ✅ | `SaveManager` |
| Creation Artifact: lives, anchors, respawn, recharge, functions (storage) | ✅ (artifact screen: O) | `data/artifact.json`, `CreationArtifact` |
| Data-driven regions (6), travel, exploration encounters | ✅ (choice window: W-004d; Dangerous lethal foes are sensed first and prompted: slip away or fight) | `data/regions.json`, `data/encounters.json`, `Exploration` |
| Injuries (from breakthroughs and combat) | ✅ | `data/injuries.json`, `Injuries` |
| Combat (auto-resolved) and techniques | ✅ techniques named in the log, playback with hp bars, spoils and loss advice in the report | `Combat`, `Techniques`, `data/enemies.json`, `data/techniques.json` |
| NPCs (named + generated), aging, monthly sim | ✅ | `data/npcs.json`, `Npcs`, `Names` |
| Dialogue (incl. favor errands for five named NPCs, C-011) | ✅ (dialogue window) | `Dialogue`, `data/dialogue/` |
| Mentorship: pointers from senior NPCs, friendly spars | ✅ (NPC menu) | `data/family.json` mentorship, `Mentorship` |
| Family: identity, courtship, marriage, dual cultivation, children, adoption, training | ✅ (NPC menu: chat, gifts, court, propose, adopt; meditation spots; child training screen) | `data/family.json`, `Family`, `Children` |
| Clans, estates, bloodlines | ✅ clan core (FAM-005), heirs (FAM-008), NPC clans core (FAM-009), bloodlines core (FAM-007), clan screen UI (FAM-005b), estates core (FAM-006) | `data/family.json`, `data/bloodlines.json`, `Clans`, `ClanData`, `Bloodlines` |
| Spirit beast companions (Beast Tamer taming, combat bonus, growth) | ✅ (character sheet, feeding, release) | `data/beasts.json`, `Beasts` |
| Cultivation methods (one main method, qi rate, realm cap) | ✅ (techniques screen) | `Techniques`, `data/techniques.json` |
| Dao insights (encounters, practice, seclusion; technique + breakthrough bonuses) | ✅ (sheet + contemplation at meditation spots) | `data/dao.json`, `Dao` |
| Heavenly Tribulations (Core Formation+, heart demon for demonic) | ✅ (prepare warning + wave screen) | `Tribulation`, `data/realms.json` |
| Grudges and gratitude (rob/kill/humiliate NPCs, kin vengeance, amends) | ✅ (NPC menu, sheet, NPC Look text, grateful NPCs repay debts and join fights, grudge holders ambush travellers) | `data/karma.json`, `Karma` |
| Secret realms (periodic openings, realm caps, guarded floors, inheritances) | ✅ (six realms with entrances across the regions; journal Opportunities, sheet Adventures) | `data/secret_realms.json`, `SecretRealms` |
| Inheritance grounds (one-claimant trials) | ✅ (inheritance ground places; journal Opportunities, sheet Adventures) | `data/inheritances.json`, `Inheritances` |
| Cave abodes (seclusion, storage chest) and arrays | ✅ (abode places; arrays from the Array Master) | `data/regions.json`, `Abodes` |
| Body tempering (Copper Skin … Vajra Body) | ✅ (meditation spots, abodes, sheet) | `data/body_tempering.json`, `BodyTempering` |
| Auctions (seasonal lots, sealed bids vs hidden NPC maximums) | ✅ (auction house in Fallen Star Market) | `data/auctions.json`, `Auctions` |
| Creation Artifact inner world and spirit garden | ✅ (artifact screen) | `InnerWorld`, `SpiritGarden` |
| World events (beast tides, tournaments, auctions, incursions) | ✅ passive effects + HUD/map/rumors; tournaments and incursion defence can be joined (LW-003) | `data/world_events.json`, `WorldEvents` |
| NPC clans and NPC sect membership, family tree, Family Home | ✅ | `NpcClans`, `FamilyHome`, `src/ui/family_screen.gd` |
| NPC sects as factions (strength, recruitment) | ✅ core (LW-002), sect hall standings (WU-002), monthly clashes and the sect's call (LW-002b) | `SectFactions` |
| Audio, autosave, export presets, credits | ✅ procedural SFX and music, autosave with toast (also on suspend), crash-safe saves, credits, title art, Steam platform stub (REL-009), Windows/Linux export presets + tools/export.sh (REL-005), Steam upload scripts and docs/RELEASE.md (REL-011, needs the owner's app/depot ids) | `Audio`, `SaveManager`, `src/ui/credits_screen.gd` |
| Content past Core Formation | ✅ Nascent Soul foes/encounters (NS-001), pills (NS-002), Myriad Peaks Ridge region (NS-003); late methods to Mahayana+ (NS-005), late people with errands (NS-004), flawless late pills (NS-002b), Soul Formation foes/encounters (NS-006); 🚧 gear past Core Formation (C-045) | |
| Life record and milestones | ✅ sheet life record (STAT-001), 22 milestones with progress on the sheet and a banner (GOAL-001, WU-006, MS-002, MS-003), journal screen (J / LT) with opportunities, errands and commissions, epilogue on final death, a yearly review banner (YEAR-001, WU-031) | `LifeStats`, `Milestones`, `data/milestones.json` |
| Ending (ascension) | 🚧 none, waiting on the owner (END-001) | |
| Inventory, techniques, character sheet, settings, pause, load screens | ✅ | `src/ui/` |
| Top-down world with interactables | ✅ placeholder art, seasonal tints and season banner, seasonal herbs and encounters with in-season news (SEASON-001/002/003), ambient particles, idle NPCs, visited regions, first-visit text for every region, a discovery on the first exploration of a region and sect home regions (TRAV-001..005), unexplored-road hints (GUIDE-014), breakthrough effect | `src/world/` |

## Lifespan as a resource (owner decision)
- Breaking through to a higher realm adds lifespan, so a cultivator who keeps progressing should **rarely die of old age**. The Creation Artifact does **not** save the player from old age.
- Lifespan can be **spent**: forbidden secret arts, demonic weapons and evil cultivator artifacts that burn years of life for power. Recklessly burning lifespan is the main way a strong cultivator dies of old age.
- Lifespan can also be extended (longevity pills, rare treasures, late-game artifact functions).

## Realm ladder
Mortal → Qi Refining (9 layers) → Foundation Establishment → Core Formation → Nascent Soul → Soul Formation →
Void Refinement → Body Integration → Mahayana → Tribulation Transcendence. Post-Qi-Refining realms have Early/Middle/Late/Peak stages.

## Open design questions (for the human)
**Most urgent (2026-10-07 planner):** these three decide what the agents build next.
1. **(F-005d) Pacing**: a sensible player reaches Core Formation at ~20 and Nascent Soul at ~36; content currently stops at Core. How long should each realm take?
2. **(C-009) The first fights**: a newcomer can't win any Qi Refining fight for ~3 in-game years. Soften the first realm, or keep it hard?
3. **(END-001) Ascension**: there is no ending at all yet. See the question below.

- (END-001) **Ascension, the ending.** Today a breakthrough at the last realm is simply refused and the run never ends. Default proposal: at Tribulation Transcendence Peak the player can attempt Ascension (the hardest tribulation; dying to it spends an artifact life as usual), and success ends the run with an epilogue screen summing up the life (realm, age, alignment, deeds, clan, descendants), after which the save is closed (or, if you want, "Continue as your clan's heir" in the mortal world). Is there an Immortal Realm to play after ascending, or is ascension the end credits?
- (FH-013) **Rerolling the spiritual root at creation.** Rerolls are free and unlimited today (talent 0.35x-4.5x), so most players will reroll for a Heavenly Root. Default: keep unlimited rerolls (agents only make the talent scale clearer). Alternatives: a fixed number of rerolls, or none (the trash-root story).
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
- (QA-007) **How lopsided should fights be?** Today realm power x3 per major realm makes combat binary: a geared player wins ~100% against any enemy of their realm and ~0% one realm up. Default the agents will aim for (QA-007d): ~60-85% win rate against an enemy of your own realm and stage, near 0% a full realm up (realm gaps stay nearly impossible, as in the genre). Is that right?
- (TRIB-001) **Heavenly Tribulations.** Default: tribulations strike at every major-realm breakthrough from Core Formation upward, as several lightning waves you survive with HP, defense, talismans and pills. Failing injures you, and the last wave can kill you, in which case the Creation Artifact respawns you and spends a life. Demonic cultivators face an extra heart-demon wave. Is this right, and should a tribulation also hit at Foundation Establishment? *(Implemented as this default, none at Foundation; the heart demon wave hits at alignment <= -300 and scales with how demonic you are. Tunable in realms.json.)*
- (QA-010) **How deadly should tribulations be?** Before tuning, a cultivator with any defense technique and gear survived every tribulation 100% of the time. Default the agents set: a typical player (Iron Fist + Stone Skin, best buyable gear) survives each tribulation ~87-90% unprepared, ~100% at Core Formation with a readied shield talisman; a deeply demonic one (alignment -1000) ~60%. A player with no techniques or gear cannot pass Core Formation lightning (they are injured on the first wave and must prepare). NPCs, who have no modelled techniques or gear, face a softer `npc_strength` so they survive about as often as a typical player. Is "you must prepare for tribulations" the right feel, and should later tribulations get deadlier than ~87%?
- (FAM-005) **Clan founding requirements.** Default: Foundation Establishment, 500 spirit stones and a claimed estate/abode, all in `data/family.json`. Can a rogue still in a sect found a clan, or must they leave or get permission? (FAM-005 core: sect members may found a clan for now; the estate requirement waits for abodes, FAM-005c.)
- (W-005/G-008) **Founding your own sect** (roadmap item 3) is not scheduled yet. Default proposal: it unlocks at Nascent Soul, needs a mountain gate place, and reuses the clan treasury/buildings model. Should it be a separate system from clans, or a clan that grows into a sect?
- (F-005d) **Cultivation pacing.** With sensible play (best qi spot reachable, joining a sect), the balance sim reaches Core Formation by age ~20 and the final realm by ~800, so lifespan never pressures anyone and pills don't matter. What pacing do you want? Agents' default proposal for a sensible, average-root player: Foundation ~25-35, Core Formation ~80-120, Nascent Soul ~300-450, with each later realm taking a large share of its lifespan, and Heavenly Roots about 2-3x faster.
- **Main story / Creation Artifact origin.** Agents keep the artifact's maker, why it chose the player and who hunts it vague until you decide. Do you want to outline the main story arc (acts, antagonist faction), or should agents propose 2-3 options for you to pick from?
- (G-011) **Sect promotion.** Default: promotion to Inner Disciple and above needs a realm minimum plus a trial fight, ranks pay a monthly stipend, and missing the monthly duty only skips the stipend (no demotion). Should neglecting duties demote or expel a disciple?
- (BEAST-001) **Taming spirit beasts.** Default: a Beast Tamer automatically tries to tame a tameable beast they defeat (15% at rank 0, up to 75%), keeps one companion (`max_companions` in data/beasts.json), and the companion adds a share of their combat stats that fades once they outgrow its realm. Should taming be a choice after the fight (tame vs slay for its materials), should non-tamers tame at all, and how many companions should a master keep?
- (DEM-001) **Devouring.** Default: after defeating a cultivator the player can devour their cultivation for qi at a big alignment cost and a heart-demon injury risk. This is the smallest demonic art; the separate demonic tree (DEM-002) stays blocked on the question above.
- (BODY-001) **Body cultivation.** Default: a separate body-tempering track that runs alongside qi cultivation (stages that add HP/defense, paid in herbs/ores and days, with injury risk), open to everyone and not tied to a profession. Should it instead be an alternative path that replaces qi cultivation (pure body cultivators), and should it extend lifespan?
- (RIV-001) **Hostile acts against NPCs.** Smallest version built: you can humiliate (only someone weaker), rob or kill any adult NPC who is not your own family; children and family members are off limits, and grudges fade 5 points a year. Should demonic players be able to harm children or their own kin (e.g. a blood-sacrifice path), and should grudges from a killing never fade?
- (GOAL-001) **Should milestones give rewards?** Default: no, just recognition (a message, later Steam achievements).
- (QA-006) **Artifact recharge cost.** `data/artifact.json` doubles the recharge price for every life ever bought (100, 200, 400 ... 409,600 for the 13th). The economy sim shows that any steady rate of violent deaths eventually empties the artifact for good: at 3 deaths per century every simulated life ended by about age 400, and at 1 per century by about age 1,400. Is that the intended "death is final eventually" pressure? Default proposal (ART-007): price scales with realm, and the doubling applies only to lives bought within the current major realm.
- (C-009) **The first fights.** A newcomer is safe (lethal Deadly foes are sensed and evaded, forced fights never kill), but cannot win any Qi Refining fight for a long while: with Iron Fist level 1 and an Iron Sword, a Qi Refining 4th Layer player beats a Mist Wolf (Qi Refining 1st Layer) about 4% of the time, because QA-007d's enemy `realm_training` assumes the typical player's level-3 techniques and best gear. So the first hours are boars, bandits, chores and meditation, and wolves only become fair after weeks of technique practice. Is that the intended pace, or should the first realm's enemies (or `realm_training[1]`) be softer so a newcomer with a starter technique can win ~50% against a 1st-layer beast?
- (RV-005) **Breakthrough pills.** Pills stacked for any realm, so four cheap Foundation pills capped the odds at Nascent Soul. Default the agents will build: each breakthrough pill only works for the realm it is made for, and only one pill can be active per attempt. Should stronger players be able to stack two pills (at a cost, e.g. an injury risk)?
- (PROF-001) **Crafting commissions.** Default being built: each month a buyer orders 1-3 of something you can craft for about twice its material value; an order you ignore simply lapses after 60 days with no penalty. Should lapsed orders cost reputation, and should famous crafters get bigger orders from sects and clans?
- (FAM-013) **NPC population over the generations.** `npc_families.population_cap` is 300 and every generated child cultivates, so few NPCs die. The world fills to the cap by year 50, then often has no births for a century until the elders die of old age. Defaults for now: keep the cap, all children cultivate. Options: some NPC children are born without usable roots (mortals live about 80 years, so the world turns over), raise the cap, or scale it by region. Which do you want?
- (LW-002b) **Sect clashes and your family.** Monthly sect clashes can kill NPC members, including the player's spouse or descendants who joined a sect (only recruitment spares them). Default: keep it as world drama (the news is posted). Should the player's family be spared, or should the player at least be warned/called to defend them?
