class_name CharacterSheet
extends PanelContainer
## Modal character overview: identity and family, sect reputation, attributes, roots and
## professions, and equipped gear with Unequip buttons. "Train children" opens
## the ChildTrainingScreen. Items live in
## InventoryScreen. Old saves without a gender get a one-time gender picker here.
## The text scrolls (PgUp/PgDn, right stick) so a long sheet still fits a Steam Deck.

signal closed

## Tallest the text area may grow before it scrolls, so the sheet fits 1280x800.
const MAX_TEXT_HEIGHT := 470.0
const SCROLL_SPEED := 900.0

var _scroll: ScrollContainer
var _text: RichTextLabel
var _recharge: Button
var _gender_row: HBoxContainer
var _equip_row: HBoxContainer
var _train_children: Button
var _family_button: Button
## Beast whose Release button awaits its confirming second press (FH-015).
var _release_confirm := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(620, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(596, 0)
	_text.resized.connect(_fit_scroll)
	_scroll.add_child(_text)
	_gender_row = HBoxContainer.new()
	_gender_row.add_theme_constant_override("separation", 8)
	_gender_row.add_child(UIStyle.label("Your gender is unknown. Choose:", 16))
	for g in Names.genders(GameState.data):
		_gender_row.add_child(UIStyle.button(g.capitalize(), func(): _choose_gender(g)))
	box.add_child(_gender_row)
	_equip_row = HBoxContainer.new()
	_equip_row.add_theme_constant_override("separation", 8)
	box.add_child(_equip_row)
	_recharge = UIStyle.button("Recharge artifact", func(): GameState.recharge_artifact())
	box.add_child(_recharge)
	_train_children = UIStyle.button("Train children", func(): EventBus.child_training_requested.emit())
	box.add_child(_train_children)
	_family_button = UIStyle.button("Family tree", func(): EventBus.family_requested.emit())
	box.add_child(_family_button)
	box.add_child(UIStyle.button("Close", close))
	EventBus.player_changed.connect(func(): if visible: _rebuild())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if not visible:
		return
	var dir := Input.get_axis("scroll_up", "scroll_down")
	if dir != 0.0:
		_scroll.scroll_vertical += int(dir * SCROLL_SPEED * delta)


## The scroll area is as tall as the text, up to MAX_TEXT_HEIGHT.
func _fit_scroll() -> void:
	_scroll.custom_minimum_size = Vector2(596, minf(_text.size.y, MAX_TEXT_HEIGHT))


func open() -> void:
	_release_confirm = ""
	_rebuild()
	_scroll.scroll_vertical = 0
	visible = true
	_default_focus().grab_focus.call_deferred()


func _default_focus() -> Button:
	if _gender_row.visible:
		return _gender_row.get_child(1) as Button
	return get_child(0).get_child(-1) as Button


func _choose_gender(gender: String) -> void:
	GameState.choose_gender(gender)
	_default_focus().grab_focus.call_deferred()


func close() -> void:
	_release_confirm = ""
	if not visible:
		return
	visible = false
	closed.emit()


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	var accent := UIStyle.ACCENT.to_html(false)
	var t := "[font_size=24][color=#%s]%s[/color][/font_size]\n" % [accent, p.name]
	var identity: Array[String] = []
	if p.gender != "":
		identity.append(p.gender.capitalize())
	if p.surname != "":
		identity.append("of the %s family" % p.surname)
	if not identity.is_empty():
		t += "%s\n" % " ".join(identity)
	t += "%s, age %d of %d\n" % [Cultivation.realm_label(p, data), p.age_years(), Cultivation.lifespan_years(p, data)]
	t += "Spiritual Root: %s\n" % SpiritualRoots.describe(p.spiritual_roots, data)
	var bloodline := Bloodlines.describe(p, data)
	if bloodline != "":
		t += "Bloodline: %s\n" % bloodline
		var bonuses := bloodline_bonus_text(data, p.bloodline)
		if bonuses != "":
			t += "  [color=#aaaaaa]%s: %s[/color]\n" % ["Grants" if p.bloodline_awakened else "Will grant", bonuses]
	t += "Cultivation speed: %.2f qi/day here\n" % Cultivation.qi_per_day(p, data, GameState.hint_density())
	var devoured := "   |   Cultivators devoured: %d" % p.devoured if p.devoured > 0 else ""
	t += "Alignment: %s (%d)%s   |   %s\n\n" % [Alignment.tier_name(p.alignment, data), p.alignment, devoured, Sects.describe(p, data)]
	var rank_line := SectFactions.rank_line(p, GameState.sect_standings())
	if rank_line != "":
		t += rank_line + "\n\n"
	var rival_line := rival_line(p, data, GameState.npcs, GameState.npc_favor)
	if rival_line != "":
		t += "[color=#%s]Rival[/color]\n  %s\n\n" % [accent, rival_line]
	_gender_row.visible = p.gender == ""
	var density := GameState.hint_density()
	var hints := Guidance.hints(p, data, density, 6, GameState.npcs, GameState.world_flags, GameState.current_region, GameClock.total_days)
	if not hints.is_empty():
		t += "[color=#%s]Next steps[/color]\n" % accent
		for line in hints:
			t += "  - %s\n" % line
		t += "\n"
	var family := Family.describe_links(p, GameState.npcs, data)
	family.append_array(Children.describe_pregnancies(p, GameState.npcs))
	if not family.is_empty():
		t += "[color=#%s]Family[/color]\n" % accent
		for line in family:
			t += "  %s\n" % line
		t += "\n"
	var karma := Karma.describe(p, GameState.npcs)
	if not karma.is_empty():
		t += "[color=#%s]Grudges & Debts[/color]\n" % accent
		for line in karma:
			t += "  %s\n" % line
		t += "\n"
	var adventures := SecretRealms.progress_lines(p, data, GameClock.total_days)
	adventures.append_array(Inheritances.progress_lines(p, data, GameState.world_flags))
	if not adventures.is_empty():
		t += "[color=#%s]Adventures[/color]\n" % accent
		for line in adventures:
			t += "  %s\n" % line
		t += "\n"
	t += "[color=#%s]Sect Reputation[/color]\n" % accent
	for line in Reputation.describe(p, data):
		t += "  %s\n" % line
	t += "\n[color=#%s]Attributes[/color]\n" % accent
	for attr in data.attributes:
		t += "  %s: %d\n" % [attr["name"], p.attribute(attr["id"])]
	var stats := Combat.stats(p, data)
	t += "\n[color=#%s]Combat[/color]\n" % accent
	t += "  Health %d   Attack %d   Defense %d   Speed %d   Crit %d%%\n" % [int(stats["max_hp"]), int(stats["attack"]), int(stats["defense"]), int(stats["speed"]), roundi(stats["crit"] * 100)]
	var body := BodyTempering.describe(p, data)
	t += "  Body: %s\n" % body[0]
	for i in range(1, body.size()):
		t += "    %s\n" % body[i]
	t += "\n[color=#%s]Equipment[/color]\n" % accent
	for slot in Equipment.SLOTS:
		var item_id := String(p.equipment.get(slot, ""))
		if item_id == "":
			t += "  %s: none\n" % slot.capitalize()
		else:
			t += "  %s: %s (%s)\n" % [slot.capitalize(), data.items[item_id]["name"], Equipment.describe_stats(data, item_id)]
	if not p.companions.is_empty():
		t += "\n[color=#%s]Spirit Beasts[/color]\n" % accent
		for line in Beasts.describe(p, data):
			t += "  %s\n" % line
	_rebuild_equip_row()
	_train_children.visible = not ChildTrainingScreen.living_children(p, GameState.npcs).is_empty()
	_family_button.visible = not (p.parents.is_empty() and p.spouses.is_empty() and p.children.is_empty())
	if Injuries.has_any(p):
		var danger := UIStyle.CATEGORY_COLORS["danger"].to_html(false)
		t += "\n[color=#%s]Injuries[/color]  (cultivation x%s, combat x%s)\n" % [danger, String.num(Injuries.cultivation_multiplier(p, data), 2), String.num(Injuries.combat_multiplier(p, data), 2)]
		for line in Injuries.describe(p, data):
			t += "  %s\n" % line
	if Buffs.has_any(p):
		t += "\n[color=#%s]Active arts[/color]\n" % accent
		for line in Buffs.describe(p):
			t += "  %s\n" % line
	if p.abode != "":
		var abode := Abodes.get_def(data, p.abode)
		t += "\n[color=#%s]Abode[/color]\n" % accent
		t += "  %s in %s (seclusion qi x%s, chest %d / %d kinds)\n" % [Abodes.abode_name(data, p.abode), Exploration.region_name(data, String(abode.get("region", ""))), String.num(float(abode.get("qi_density", 1.0)), 2), p.abode_storage.size(), Abodes.storage_slots(p, data)]
	t += "\n[color=#%s]Creation Artifact[/color]\n" % accent
	for line in CreationArtifact.describe(p, data):
		t += "  %s\n" % line
	_recharge.text = "Recharge artifact (%d spirit stones)" % CreationArtifact.recharge_cost(p, data)
	_recharge.disabled = p.item_count("spirit_stone") < CreationArtifact.recharge_cost(p, data) or p.artifact_lives >= int(data.artifact.get("max_lives", 9))
	t += "\n[color=#%s]Techniques[/color]\n" % accent
	if p.techniques.is_empty():
		t += "  None yet. Learn one from a manual.\n"
	for tech_id in TechniquesScreen.listed_ids(p, data):
		if Techniques.knows(p, tech_id):
			t += "  %s (level %d)\n" % [data.techniques[tech_id].name, Techniques.level(p, tech_id)]
	t += "\n[color=#%s]Dao insights[/color]\n" % accent
	var insights := Dao.known_ids(p, data)
	if insights.is_empty():
		t += "  None glimpsed yet. Rare encounters and long practice of a technique can reveal one.\n"
	for insight_id in insights:
		var insight := Dao.def_of(data, insight_id)
		t += "  %s %d/%d (+%d%% to its arts), %s\n" % [insight["name"], Dao.level(p, insight_id), Dao.max_level(data), roundi(float(insight.get("technique_bonus", 0.0)) * Dao.level(p, insight_id) * 100), Dao.progress_text(p, data, insight_id)]
	if not insights.is_empty():
		t += "  Breakthrough chance +%d%%. Contemplate an insight at a meditation spot.\n" % roundi(Dao.breakthrough_bonus(p, data) * 100)
	t += "\n[color=#%s]Professions[/color]\n" % accent
	if p.professions.is_empty():
		t += "  None yet. Work at the Village Workshop to learn a craft.\n"
	for prof_id in p.professions:
		var def: ProfessionDef = data.professions[prof_id]
		var rank := Professions.rank_of(p, prof_id)
		var next := "max" if rank >= Professions.max_rank(data) else "%d / %d xp" % [int(Professions.xp_of(p, prof_id)), int(def.xp_to_next(rank))]
		t += "  %s (%s)\n" % [Professions.rank_title(p, data, prof_id), next]
	t += "\n[color=#%s]Life record[/color]\n" % accent
	var record := LifeStats.lines(p)
	if record.is_empty():
		t += "  Nothing of note yet.\n"
	for line in record:
		t += "  %s\n" % line
	t += "\n[color=#%s]Milestones (%d of %d)[/color]\n" % [accent, p.milestones.size(), data.milestones.size()]
	var upcoming := 0
	for def in data.milestones:
		var mid := String(def["id"])
		if p.milestones.has(mid):
			t += "  %s: %s\n" % [def["name"], def.get("description", "")]
		elif upcoming < 3:
			upcoming += 1
			var count := Milestones.progress_text(p, data, GameState.world_flags, GameState.clan, mid)
			t += "  [color=#888888]%s%s[/color]\n" % [def["name"], "" if count == "" else " (%s)" % count]
	t += "\n[color=#888888]Press [I] for your inventory and [K] for techniques.[/color]"
	_text.text = t


## "Han Li, Qi Refining (ahead of you), grudge 3" for the player's named rival,
## "<name> has died" if they are dead, "" when there is no rival.
static func rival_line(c: CharacterData, data: GameData, people: Dictionary, favor: Dictionary) -> String:
	if c.rival == "" or not people.has(c.rival):
		return ""
	var r: CharacterData = people[c.rival]
	if not r.alive:
		return "%s has died." % r.name
	var relation := {"stronger": "ahead of you", "weaker": "behind you"}.get(Rivals.relation(c, r), "your equal") as String
	var line := "%s, %s (%s)" % [r.name, Cultivation.realm_label(r, data), relation]
	var grudge := Karma.grudge(c, r.id)
	if grudge != 0:
		line += ", grudge %d" % grudge
	var fav := int(favor.get(r.id, 0))
	if fav != 0:
		line += ", favor %d" % fav
	return line


## One Unequip button per filled equipment slot.
## "+15% cultivation speed, +10% attack" for a bloodline's bonuses.
static func bloodline_bonus_text(data: GameData, bloodline_id: String) -> String:
	var names := {"qi_mult": "cultivation speed", "breakthrough": "breakthrough chance", "max_hp": "health"}
	var parts: PackedStringArray = []
	var bonuses: Dictionary = Bloodlines.def(data, bloodline_id).get("bonuses", {})
	for key in Bloodlines.BONUS_KEYS:
		if bonuses.has(key):
			parts.append("%+d%% %s" % [roundi(float(bonuses[key]) * 100), names.get(key, key.replace("_", " "))])
	var attrs := Bloodlines.attribute_bonuses(data, bloodline_id)
	for attr: Dictionary in data.attributes:
		if attrs.has(attr["id"]):
			parts.append("%+d %s" % [int(attrs[attr["id"]]), attr.get("name", attr["id"])])
	var drift := int(Bloodlines.def(data, bloodline_id).get("alignment_drift", 0))
	if drift != 0:
		parts.append("alignment %+d a year" % drift)
	return ", ".join(parts)


## Unequip buttons for worn gear and "Feed <beast>" for spirit beast companions.
func _rebuild_equip_row() -> void:
	for child in _equip_row.get_children():
		_equip_row.remove_child(child)
		child.queue_free()
	for beast_id in GameState.player.companions:
		var food := Beasts.best_food(GameState.player, GameState.data)
		var label := "Feed %s" % Beasts.beast_name(GameState.data, beast_id)
		if food != "":
			label += " (%s)" % GameState.data.items[food].get("name", food)
		var feed := UIStyle.button(label, func(): GameState.feed_companion(beast_id))
		feed.name = "feed_" + beast_id
		feed.disabled = food == "" or Beasts.check_feed(GameState.player, GameState.data, beast_id, food) != ""
		_equip_row.add_child(feed)
		var release := UIStyle.button("Confirm release?" if _release_confirm == beast_id else "Release", _release_pressed.bind(beast_id))
		release.name = "release_" + beast_id
		if _release_confirm == beast_id:
			release.focus_exited.connect(_release_focus_lost.bind(release).call_deferred)
		_equip_row.add_child(release)
	var p := GameState.player
	for slot in Equipment.SLOTS:
		var item_id := String(p.equipment.get(slot, ""))
		if item_id != "":
			var b := UIStyle.button("Unequip %s" % GameState.data.items[item_id]["name"], _unequip.bind(slot))
			b.name = "unequip_" + slot
			_equip_row.add_child(b)
	_equip_row.visible = _equip_row.get_child_count() > 0


## First press arms "Confirm release?", the second frees the beast.
func _release_pressed(beast_id: String) -> void:
	if _release_confirm != beast_id:
		_release_confirm = beast_id
		_rebuild_equip_row()
		var armed := _equip_row.get_node_or_null("release_" + beast_id) as Button
		if armed != null:
			_focus_if_in_tree.call_deferred(armed)
		return
	_release_confirm = ""
	GameState.release_companion(GameState.player.companions.find(beast_id))
	_rebuild_equip_row()
	_default_focus().grab_focus.call_deferred()


func _focus_if_in_tree(button: Control) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


## Moving focus away from an armed Release button disarms it.
func _release_focus_lost(button: Button) -> void:
	if _release_confirm == "" or (is_instance_valid(button) and button.has_focus()):
		return
	_release_confirm = ""
	_rebuild_equip_row()


func _unequip(slot: String) -> void:
	GameState.unequip(slot)
	# The row was rebuilt by player_changed; keep gamepad focus inside the sheet.
	var target: Button = _equip_row.get_child(0) if _equip_row.get_child_count() > 0 else _default_focus()
	target.grab_focus.call_deferred()
