# FOLK-027: Your own birthday

Role: systems. Reference: Stardew Valley's villager birthdays turned around (friends remember yours); The Scroll of Taiwu's
family celebrating milestones. Mechanics only.

## Planner default (small, recorded in DESIGN.md "Open design questions")
Age keeps counting up at New Year (the traditional reckoning, so nothing about ageing or lifespan changes). The birthday
is a celebration day only.

## Build
1. `CharacterData.birthday: int = -1` (day of year, 0-based, same meaning as `Folk.birthday_day` returns for NPCs).
   to_dict/from_dict; when it is missing or -1 in an old save, use the same hash Folk uses for generated villagers
   (deterministic, no rng) on the character's name. No SAVE_VERSION bump needed (defaulted field); if you do bump, add
   the fixture per CLAUDE.md rule 5.
2. `CharacterFactory`: roll `birthday` from the passed rng at creation (any day of the year).
3. `Folk.player_birthday_today(c, data, day) -> bool` and `Folk.player_birthday_line(npc, c, data, day) -> String`:
   on the player's birthday, the first chat that day with each villager at folk tier >= 1 (Acquaintance or better; use the
   tier constants Folk already has) says a line from `family.json folk_greetings.player_birthday` (new list, >= 4 lines,
   {player}; validated like `birthday`), +2 favor once per villager per year. NPC's own birthday line wins if both fall
   the same day. Store "greeted this year" the way FOLK-022/C-326 store birthday gifts (look at Folk's birthday memory and
   reuse that pattern).
4. Family: if the player has a spouse or a living child in the region where they stand, the first time they are in the
   Family Home that day (or on the first chat with that family member if there is no home), they get one item from
   `family.json player_birthday_gift` (new optional field, an items.json id; set it to an existing cheap cooked dish,
   e.g. a porridge or noodle dish already in items.json; validate the id). Once per year.
5. Guidance "Today" line: `Today is your birthday.` (fits GUIDE-220's 42 chars).
6. Character sheet: "Born: Month M, Day D" using the same `Calendar.month_of/day_of` formatting Folk's book uses.
   HUD: show WU-482's cake marker over the player on the day (one call; it already exists for villagers).

## Tests
- Factory rolls a birthday in range with a seeded rng; old-save default is deterministic for a name.
- Greeting once per villager per year, +2 favor, tier gate, NPC-birthday precedence.
- Family gift once per year; no spouse/child -> none.
- Today line only on the day. Save round-trip.
- GameState integration test: talk to a friend on your birthday (tests/unit/test_game_session.gd style).

## Acceptance
`tools/test.sh` ALL CHECKS PASSED. Commit `Follow-ups:` to ask content for per-villager `player_birthday_line`s (C-333).
