class_name CharacterSheet
extends PanelContainer
## Modal character overview: identity and family, attributes, roots and
## professions. Items live in InventoryScreen. Old saves without a gender get a
## one-time gender picker here.

signal closed

var _text: RichTextLabel
var _recharge: Button
var _gender_row: HBoxContainer


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	custom_minimum_size = Vector2(620, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(596, 0)
	box.add_child(_text)
	_gender_row = HBoxContainer.new()
	_gender_row.add_theme_constant_override("separation", 8)
	_gender_row.add_child(UIStyle.label("Your gender is unknown. Choose:", 16))
	for g in Names.genders(GameState.data):
		_gender_row.add_child(UIStyle.button(g.capitalize(), func(): _choose_gender(g)))
	box.add_child(_gender_row)
	_recharge = UIStyle.button("Recharge artifact", func(): GameState.recharge_artifact())
	box.add_child(_recharge)
	box.add_child(UIStyle.button("Close", close))
	EventBus.player_changed.connect(func(): if visible: _rebuild())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_rebuild()
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
	t += "Cultivation speed: %.2f qi/day here\n" % Cultivation.qi_per_day(p, data, Exploration.qi_density(data, GameState.current_region) * Sects.cultivation_bonus(p, data))
	t += "Alignment: %s (%d)   |   %s\n\n" % [Alignment.tier_name(p.alignment, data), p.alignment, Sects.describe(p, data)]
	_gender_row.visible = p.gender == ""
	var family := Family.describe_links(p, GameState.npcs, data)
	if not family.is_empty():
		t += "[color=#%s]Family[/color]\n" % accent
		for line in family:
			t += "  %s\n" % line
		t += "\n"
	t += "[color=#%s]Attributes[/color]\n" % accent
	for attr in data.attributes:
		t += "  %s: %d\n" % [attr["name"], p.attribute(attr["id"])]
	var stats := Combat.stats(p, data)
	t += "\n[color=#%s]Combat[/color]\n" % accent
	t += "  Health %d   Attack %d   Defense %d   Speed %d   Crit %d%%\n" % [int(stats["max_hp"]), int(stats["attack"]), int(stats["defense"]), int(stats["speed"]), roundi(stats["crit"] * 100)]
	if Injuries.has_any(p):
		var danger := UIStyle.CATEGORY_COLORS["danger"].to_html(false)
		t += "\n[color=#%s]Injuries[/color]  (cultivation x%s, combat x%s)\n" % [danger, String.num(Injuries.cultivation_multiplier(p, data), 2), String.num(Injuries.combat_multiplier(p, data), 2)]
		for line in Injuries.describe(p, data):
			t += "  %s\n" % line
	if Buffs.has_any(p):
		t += "\n[color=#%s]Active arts[/color]\n" % accent
		for line in Buffs.describe(p):
			t += "  %s\n" % line
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
	t += "\n[color=#%s]Professions[/color]\n" % accent
	if p.professions.is_empty():
		t += "  None yet. Work at the Village Workshop to learn a craft.\n"
	for prof_id in p.professions:
		var def: ProfessionDef = data.professions[prof_id]
		var rank := Professions.rank_of(p, prof_id)
		var next := "max" if rank >= Professions.max_rank(data) else "%d / %d xp" % [int(Professions.xp_of(p, prof_id)), int(def.xp_to_next(rank))]
		t += "  %s (%s)\n" % [Professions.rank_title(p, data, prof_id), next]
	t += "\n[color=#888888]Press [I] for your inventory and [K] for techniques.[/color]"
	_text.text = t
