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
const LEFT_WIDTH := 250.0
const ELEMENT_COLORS := {
	"metal": Color("c8ccd4"), "wood": Color("6fbf5a"), "water": Color("4a9be8"),
	"fire": Color("e8603a"), "earth": Color("c49a4a"),
}

var _scroll: ScrollContainer
var _portrait: TextureRect
var _name_label: Label
var _realm_label: Label
var _age_label: Label
var _qi_bar: ProgressBar
var _qi_label: Label
var _root_title: Label
var _root_box: VBoxContainer
var _text: RichTextLabel
var _recharge: Button
var _action_row: HFlowContainer
var _gender_row: HBoxContainer
var _equip_row: HBoxContainer
var _train_children: Button
var _family_button: Button
## Beast whose Release button awaits its confirming second press (FH-015).
var _release_confirm := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(620 + LEFT_WIDTH + 12, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	box.add_child(columns)
	columns.add_child(_build_left_column())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(596, 0)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	_action_row = HFlowContainer.new()
	_action_row.add_theme_constant_override("h_separation", 12)
	_action_row.add_theme_constant_override("v_separation", 8)
	box.add_child(_action_row)
	_recharge = UIStyle.button("Recharge artifact", func(): GameState.recharge_artifact())
	_action_row.add_child(_recharge)
	_train_children = UIStyle.button("Train children", func(): EventBus.child_training_requested.emit())
	_action_row.add_child(_train_children)
	_family_button = UIStyle.button("Family tree", func(): EventBus.family_requested.emit())
	_action_row.add_child(_family_button)
	_action_row.add_child(UIStyle.button("Close", close))
	EventBus.player_changed.connect(func(): if visible: _rebuild())


func _build_left_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	col.add_theme_constant_override("separation", 6)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIStyle.panel_style())
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PixelFigure.SIZE * 4)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_portrait)
	var framed := CenterContainer.new()
	framed.add_child(frame)
	col.add_child(framed)
	_name_label = UIStyle.label("", 24, UIStyle.ACCENT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name_label)
	_age_label = UIStyle.label("", 14, Color("bbbbbb"))
	_age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_age_label)
	_realm_label = UIStyle.label("", 17)
	_realm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_realm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_realm_label)
	_qi_bar = ProgressBar.new()
	_qi_bar.show_percentage = false
	_qi_bar.custom_minimum_size = Vector2(0, 12)
	col.add_child(_qi_bar)
	_qi_label = UIStyle.label("", 13, Color("bbbbbb"))
	_qi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_qi_label)
	_root_title = UIStyle.label("", 15, UIStyle.ACCENT)
	col.add_child(_root_title)
	_root_box = VBoxContainer.new()
	_root_box.add_theme_constant_override("separation", 3)
	col.add_child(_root_box)
	return col


## Fills the left column from the player: portrait, name, age, realm, qi bar, root bars.
func _rebuild_left() -> void:
	var p := GameState.player
	var data := GameState.data
	_portrait.texture = PixelFigure.frame(PlayerLook.of(p, data), "down", 0)
	_name_label.text = p.name
	_age_label.text = "Age %d of %d" % [p.age_years(), Cultivation.lifespan_years(p, data)]
	_realm_label.text = Cultivation.realm_label(p, data)
	var need := Cultivation.qi_required(p, data)
	_qi_bar.max_value = maxf(need, 1.0)
	_qi_bar.value = minf(p.qi, need)
	_qi_label.text = "Qi %d / %d" % [int(p.qi), int(need)] if not Cultivation.is_at_bottleneck(p, data) else "At the bottleneck"
	_root_title.text = SpiritualRoots.grade_for(p.spiritual_roots, data).get("name", "No Spiritual Root")
	for child in _root_box.get_children():
		_root_box.remove_child(child)
		child.queue_free()
	for row in root_rows(p.spiritual_roots, data):
		var line := HBoxContainer.new()
		line.name = "root_" + String(row["id"])
		line.add_theme_constant_override("separation", 6)
		var name_label := UIStyle.label(String(row["name"]), 14)
		name_label.custom_minimum_size = Vector2(52, 0)
		line.add_child(name_label)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = int(row["value"])
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0, 10)
		var fill := StyleBoxFlat.new()
		fill.bg_color = ELEMENT_COLORS.get(String(row["id"]), Color.WHITE)
		bar.add_theme_stylebox_override("fill", fill)
		line.add_child(bar)
		var value_label := UIStyle.label(str(int(row["value"])), 14)
		value_label.custom_minimum_size = Vector2(28, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value_label)
		_root_box.add_child(line)


## One row per element, in data order: {id, name, value 0-100}; a missing element is 0.
static func root_rows(roots: Dictionary, data: GameData) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for e in data.root_elements:
		rows.append({"id": e["id"], "name": e["name"], "value": int(roots.get(e["id"], 0))})
	return rows


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
	_scroll.custom_minimum_size = Vector2(620, minf(_text.size.y, MAX_TEXT_HEIGHT))


func open() -> void:
	_release_confirm = ""
	_rebuild()
	_scroll.scroll_vertical = 0
	visible = true
	_default_focus().grab_focus.call_deferred()


func _default_focus() -> Button:
	if _gender_row.visible:
		return _gender_row.get_child(1) as Button
	return _action_row.get_child(-1) as Button


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
	_rebuild_left()
	var t := ""
	var identity: Array[String] = []
	if p.gender != "":
		identity.append(p.gender.capitalize())
	if p.surname != "":
		identity.append("of the %s family" % p.surname)
	if not identity.is_empty():
		t += "%s\n" % " ".join(identity)
	var bloodline := Bloodlines.describe(p, data)
	if bloodline != "":
		t += "Bloodline: %s\n" % bloodline
		var bonuses := bloodline_bonus_text(data, p.bloodline)
		if bonuses != "":
			t += "  [color=#aaaaaa]%s: %s[/color]\n" % ["Grants" if p.bloodline_awakened else "Will grant", bonuses]
	t += "Cultivation speed: %.2f qi/day here\n" % Cultivation.qi_per_day(p, data, GameState.hint_density())
	var devoured := "   |   Cultivators devoured: %d" % p.devoured if p.devoured > 0 else ""
	t += "Alignment: %s (%d)%s   |   %s\n\n" % [Alignment.tier_name(p.alignment, data), p.alignment, devoured, Sects.describe(p, data)]
	if p.gather_xp > 0:
		t += "Herb lore: %s (%d)\n" % [HerbLore.rank_name(GameState.data.herb_lore, p.gather_xp), p.gather_xp]
	if p.fishing_xp > 0:
		t += "Fishing: %s (%d)\n" % [Fishing.rank_name(p.fishing_xp), p.fishing_xp]
	var rank_line := SectFactions.rank_line(p, GameState.sect_standings())
	var contribution := contribution_line(p)
	if rank_line != "":
		t += rank_line + "\n" + (contribution + "\n" if contribution != "" else "") + "\n"
	elif contribution != "":
		t += contribution + "\n\n"
	var rival_line := rival_line(p, data, GameState.npcs, GameState.npc_favor, GameState.world_flags, GameState.current_region)
	if rival_line != "":
		t += "[color=#%s]Rival[/color]\n  %s\n\n" % [accent, rival_line]
	_gender_row.visible = p.gender == ""
	var density := GameState.hint_density()
	var hints := Guidance.hints(p, data, density, 4, GameState.npcs, GameState.world_flags, GameState.current_region, GameClock.total_days, GameState.npc_favor)
	if not hints.is_empty():
		t += "[color=#%s]Next steps[/color]\n" % accent
		t += next_steps_text(hints, InputConfig.current_label("toggle_journal")) + "\n"
	var family := Family.describe_links(p, GameState.npcs, data)
	family.append_array(Children.describe_pregnancies(p, GameState.npcs))
	if not family.is_empty():
		t += "[color=#%s]Family[/color]\n" % accent
		for line in family:
			t += "  %s\n" % (line if p.artifact_lives != 0 or not line.begins_with("Lives:") else "[color=#%s]%s[/color]" % [UIStyle.danger_color("Deadly").to_html(false), line])
		t += "\n"
	var karma := Karma.describe(p, GameState.npcs, GameState.data)
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
	var renown := Renown.describe(p, data)
	if not renown.is_empty():
		t += "[color=#%s]Renown[/color]\n" % accent
		for line in renown:
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
	var strongest := strongest_foe_line(data, GameState.world_flags)
	if strongest != "":
		t += "  %s\n" % strongest
	var people_lines := people_lines(p, data, GameState.npcs, GameState.npc_favor, 6, GameState.world_flags, GameClock.total_days)
	if not people_lines.is_empty():
		t += "\n[color=#%s]People you know[/color]\n" % accent
		for line in people_lines:
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


## WU-159: "Strongest foe beaten: <realm>" from the highest beat_realm flag set, "" when none.
static func strongest_foe_line(data: GameData, flags: Dictionary) -> String:
	for i in range(data.realms.size() - 1, -1, -1):
		if flags.get(Guidance.beat_realm_flag(data.realms[i].id), false):
			return "Strongest foe beaten: %s" % data.realms[i].name
	return ""


## "Han Li, Qi Refining (far ahead of you), a slight" for the player's named rival,
## "<name> has died" if they are dead, "" when there is no rival or you have not met yet.
## WU-167: at most 3 hint lines; when more were found, a dim pointer to the journal.
static func next_steps_text(hints: PackedStringArray, journal_key: String) -> String:
	var t := ""
	for i in mini(hints.size(), 3):
		t += "  - %s\n" % hints[i]
	if hints.size() > 3:
		t += "[color=#%s]  More in the Journal (%s)[/color]\n" % [UIStyle.HINT.to_html(false), journal_key]
	return t


## "Contribution: M to spend (lifetime L)" for sect members; "" for rogues.
static func contribution_line(c: CharacterData) -> String:
	if c.is_rogue():
		return ""
	return "Contribution: %d to spend (lifetime %d)" % [Sects.contribution_balance(c), int(c.sect.get("contribution", 0))]


static func rival_line(c: CharacterData, data: GameData, people: Dictionary, favor: Dictionary, flags: Dictionary = {}, region_id: String = "") -> String:
	if not flags.get(Rivals.FIRST_MEETING_FLAG, false) or c.rival == "" or not people.has(c.rival):
		return ""
	var r: CharacterData = people[c.rival]
	if not r.alive:
		return "%s has died." % r.name
	var relation := Rivals.relation_text(c, r)
	var feeling := Rivals.attitude_text(Rivals.attitude(c, r, int(favor.get(r.id, 0)), data))
	if feeling != "":
		relation += "; " + feeling
	var where := Rivals.where_text(r, data, region_id)  # WU-174: only when the rival is elsewhere
	var line := "%s, %s%s (%s)" % [r.name, Cultivation.realm_label(r, data), where, relation]
	var grudge := Karma.grudge(c, r.id)
	if grudge != 0:
		line += ", " + Karma.grudge_word(grudge, data)
	var fav := int(favor.get(r.id, 0))
	if fav != 0 and feeling == "":
		line += ", " + favor_word(fav, data)
	var record := Rivals.bout_record_text(flags)
	if record != "":
		line += " (%s)" % record
	return line


## WU-105: up to `limit` living non-family NPCs with the highest favor, as
## "Name, Realm, in Region: friendly". Strangers (favor 0) are left out. With `today` >= 0, a
## person waiting on a letter request gets "(asked for <item>, N days left)" (WU-115).
static func people_lines(c: CharacterData, data: GameData, people: Dictionary, favor: Dictionary, limit: int = 6, flags: Dictionary = {}, today: int = -1) -> PackedStringArray:
	var ranked: Array = []
	var ids: Dictionary = {}  # WU-178: debts and grudges list someone even at favor 0
	for id: String in favor:
		ids[id] = true
	for id: String in c.gratitude:
		ids[id] = true
	for id: String in c.grudges:
		ids[id] = true
	for id: String in ids:
		var other: CharacterData = people.get(id)
		var f := int(favor.get(id, 0))
		var owed := Karma.gratitude(c, id)
		var held := Karma.grudge(c, id)
		if other == null or not other.alive or id == c.rival:
			continue
		if f == 0 and owed <= 0 and held <= 0:
			continue
		if c.parents.has(id) or c.children.has(id) or c.spouses.has(id):
			continue
		ranked.append([f, other, id, owed, held])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		if a[3] != b[3]:
			return a[3] > b[3]
		return String(a[1].name) < String(b[1].name))
	var out := PackedStringArray()
	for entry: Array in ranked.slice(0, limit):
		var other: CharacterData = entry[1]
		var region_id := Npcs.region_of(other, data)
		var where := String(data.regions.get(region_id, {}).get("name", region_id))
		var line := "%s, %s%s: %s" % [other.name, Cultivation.realm_label(other, data), ", in %s" % where if where != "" else "", favor_word(int(entry[0]), data)]
		var tastes := Family.known_tastes(flags, data, String(entry[2]))
		var liked := 0
		for item_id: String in tastes:
			if int(tastes[item_id]) > 0:
				liked += 1
		if liked >= 1:
			line += " (likes %d known)" % liked
		var request := Letters.open_request(c, String(entry[2]), today) if today >= 0 else {}
		if not request.is_empty():
			var item_id := String(request["item"])
			line += " (asked for %s, %d days left)" % [String(data.items.get(item_id, {}).get("name", item_id)), int(request["until"]) - today]
		if int(entry[3]) >= int(data.karma.get("gratitude", {}).get("repay", {}).get("min_gratitude", 1)) and int(entry[3]) > 0:
			line += " (owes you)"
		if int(entry[4]) > 0:
			line += " (holds a grudge)"
		out.append(line)
	return out


## A word for how much `favor` an NPC has for you, from the courtship thresholds.
static func favor_word(favor: int, data: GameData) -> String:
	if favor < 0:
		return "cold"
	if favor >= int(data.family.get("proposal", {}).get("min_favor", 1000000)):
		return "devoted"
	if favor >= int(data.family.get("courtship", {}).get("min_favor", 1000000)):
		return "fond"
	return "friendly" if favor >= 10 else "acquainted"


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
