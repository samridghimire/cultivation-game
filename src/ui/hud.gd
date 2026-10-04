extends CanvasLayer
## In-game overlay: status panel, message log, interaction prompt, and modal
## windows (choice menu, toggleable screens, death screen).

const MAIN_MENU := "res://src/ui/main_menu.tscn"
const MAX_LOG_LINES := 60
## Lifespan cue thresholds (fraction of the lifespan left).
const LIFESPAN_WARNING := 0.15
const LIFESPAN_DANGER := 0.05

var _age: Label
var _status: Label
var _qi_bar: ProgressBar
var _bottleneck: Label
var _injuries: Label
var _hint: Label
var _log: RichTextLabel
var _prompt: Label
var _choice_menu: ChoiceMenu
## Toggleable modal screens keyed by the input action that opens them. Each
## must have open(), close() and a `closed` signal.
var _screens: Dictionary = {}
var _combat_report: CombatReport
var _dialogue: DialogueWindow
var _encounter: EncounterWindow
var _pause_menu: PauseMenu
var _settings: SettingsScreen
var _load_screen: LoadScreen
var _help: HelpScreen
var _crafting: CraftingScreen
var _mission_board: MissionBoard
var _child_training: ChildTrainingScreen
var _banner: Banner
var _respawn: RespawnScreen
var _death_screen: Control


func _ready() -> void:
	_build_status_panel()
	_build_log()
	_prompt = UIStyle.label("", 18, UIStyle.ACCENT)
	_set_anchored_rect(_prompt, Vector4(0, 1, 1, 1), Vector4(0, -100, 0, -70))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)

	_choice_menu = ChoiceMenu.new()
	_choice_menu.closed.connect(_update_modal)
	add_child(UIStyle.centered(_choice_menu))
	_add_screen("toggle_character_sheet", CharacterSheet.new())
	_add_screen("toggle_inventory", InventoryScreen.new())
	_add_screen("toggle_techniques", TechniquesScreen.new())
	_add_screen("toggle_artifact", ArtifactScreen.new())
	_add_screen("toggle_map", WorldMapScreen.new())
	_add_screen("toggle_message_log", MessageLogScreen.new())
	_add_screen("toggle_clan", ClanScreen.new())
	_crafting = CraftingScreen.new()
	_crafting.closed.connect(_update_modal)
	add_child(UIStyle.centered(_crafting))
	_mission_board = MissionBoard.new()
	_mission_board.closed.connect(_update_modal)
	add_child(UIStyle.centered(_mission_board))
	_child_training = ChildTrainingScreen.new()
	_child_training.closed.connect(_update_modal)
	add_child(UIStyle.centered(_child_training))
	_combat_report = CombatReport.new()
	_combat_report.closed.connect(_update_modal)
	add_child(UIStyle.centered(_combat_report))
	_dialogue = DialogueWindow.new()
	_dialogue.closed.connect(_update_modal)
	add_child(UIStyle.centered(_dialogue))
	_encounter = EncounterWindow.new()
	_encounter.closed.connect(_update_modal)
	add_child(UIStyle.centered(_encounter))
	_pause_menu = PauseMenu.new()
	_pause_menu.closed.connect(_update_modal)
	add_child(UIStyle.centered(_pause_menu))
	_settings = SettingsScreen.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(UIStyle.centered(_settings))
	_pause_menu.settings_requested.connect(_open_settings)
	_load_screen = LoadScreen.new()
	_load_screen.closed.connect(_on_load_closed)
	_load_screen.slot_chosen.connect(_on_slot_chosen)
	add_child(UIStyle.centered(_load_screen))
	_pause_menu.load_requested.connect(_open_load)
	_help = HelpScreen.new()
	_help.closed.connect(_on_settings_closed)
	add_child(UIStyle.centered(_help))
	_pause_menu.help_requested.connect(_open_help)
	_respawn = RespawnScreen.new()
	_respawn.closed.connect(_update_modal)
	add_child(UIStyle.centered(_respawn))
	_combat_report.closed.connect(_open_pending_respawn)
	_banner = Banner.new()
	add_child(_banner)
	_build_death_screen()

	EventBus.player_changed.connect(_refresh)
	EventBus.session_started.connect(_refresh)
	EventBus.region_changed.connect(func(_id): _refresh())
	EventBus.message_posted.connect(_on_message)
	Settings.changed.connect(func(key: String, _v): if key == "show_hints": _refresh())
	EventBus.interaction_target_changed.connect(_on_target_changed)
	EventBus.interaction_menu_requested.connect(_on_menu_requested)
	EventBus.crafting_requested.connect(_on_crafting_requested)
	EventBus.mission_board_requested.connect(_on_mission_board_requested)
	EventBus.child_training_requested.connect(_on_child_training_requested)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(func(_anchor_id: String, _lives: int): _open_pending_respawn())
	EventBus.combat_finished.connect(_on_combat_finished)
	EventBus.breakthrough_attempted.connect(_on_breakthrough)
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.dialogue_ended.connect(func(_id): _dialogue.close())
	EventBus.encounter_choice_requested.connect(_on_encounter_choice_requested)
	EventBus.encounter_choice_resolved.connect(_encounter.close)
	_refresh()
	# A respawn that moved the player reloads the world; ask where to awaken now.
	_open_pending_respawn.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _choice_menu.visible or _dialogue.visible or _encounter.visible or _combat_report.visible or _respawn.visible or _pause_menu.visible or _settings.visible or _help.visible or _load_screen.visible or _death_screen.visible:
		return
	if event.is_action_pressed("pause_menu"):
		# Consumed here so the world's own Esc handling never runs mid-session.
		get_viewport().set_input_as_handled()
		_close_screens()
		_pause_menu.open()
		_update_modal()
		return
	for action in _screens:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			var screen: Control = _screens[action]
			if screen.visible:
				screen.close()
			else:
				_close_screens()
				screen.open()
				_update_modal()
			return


func _add_screen(action: String, screen: Control) -> void:
	_screens[action] = screen
	screen.closed.connect(_update_modal)
	add_child(UIStyle.centered(screen))


func _close_screens() -> void:
	for screen in _screens.values():
		screen.close()
	_crafting.close()
	_mission_board.close()
	_child_training.close()


func _on_crafting_requested(prof_id: String) -> void:
	_crafting.open(prof_id)
	_update_modal()


func _on_mission_board_requested() -> void:
	_mission_board.open()
	_update_modal()


func _on_child_training_requested() -> void:
	_close_screens()
	_child_training.open()
	_update_modal()


func _any_screen_open() -> bool:
	return _crafting.visible or _mission_board.visible or _child_training.visible or _screens.values().any(func(s): return s.visible)


func _build_status_panel() -> void:
	var panel := UIStyle.panel(Vector2(340, 0))
	panel.position = Vector2(16, 16)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_age = UIStyle.label("", 15)
	box.add_child(_age)
	_status = UIStyle.label("", 15)
	box.add_child(_status)
	_qi_bar = ProgressBar.new()
	_qi_bar.custom_minimum_size = Vector2(300, 14)
	_qi_bar.show_percentage = false
	box.add_child(_qi_bar)
	_bottleneck = UIStyle.label("", 14, UIStyle.ACCENT)
	_bottleneck.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_bottleneck)
	_injuries = UIStyle.label("", 14, UIStyle.CATEGORY_COLORS["danger"])
	_injuries.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_injuries)
	_hint = UIStyle.label("", 14, Color("9fd3c7"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(316, 0)
	box.add_child(_hint)
	box.add_child(UIStyle.label("[E] interact   [C] character   [I] inventory   [K] techniques   [M] map   [L] log   [O] artifact   [G] clan   [F5] save   [Esc] pause", 12, Color(0.7, 0.7, 0.7)))
	add_child(panel)


func _build_log() -> void:
	var panel := UIStyle.panel()
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(496, 156)
	_log.add_theme_font_size_override("normal_font_size", 14)
	panel.add_child(_log)
	add_child(panel)
	_set_anchored_rect(panel, Vector4(0, 1, 0, 1), Vector4(16, -196, 536, -16))


## Anchors and offsets as (left, top, right, bottom).
func _set_anchored_rect(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


func _build_death_screen() -> void:
	var panel := UIStyle.panel(Vector2(460, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(UIStyle.label("Your Dao has ended.", 28, UIStyle.CATEGORY_COLORS["danger"]))
	var cause := UIStyle.label("", 16)
	cause.name = "Cause"
	cause.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cause)
	box.add_child(UIStyle.button("Return to Main Menu", _return_to_menu))
	_death_screen = UIStyle.centered(panel)
	_death_screen.visible = false
	add_child(_death_screen)


func _refresh() -> void:
	var p := GameState.player
	if p == null:
		return
	var data := GameState.data
	var lifespan := Cultivation.lifespan_years(p, data)
	var years_left := Cultivation.years_left(p, data)
	var age_cue := lifespan_category(years_left, lifespan)
	_age.text = "%s   Age %d / %d" % [p.name, p.age_years(), lifespan]
	if age_cue != "":
		_age.text += "   (%d %s left)" % [years_left, "year" if years_left == 1 else "years"]
	_age.add_theme_color_override("font_color", UIStyle.CATEGORY_COLORS.get(age_cue, Color.WHITE))
	var lines: PackedStringArray = [
		Cultivation.realm_label(p, data),
		"Qi: %d / %d" % [int(p.qi), int(Cultivation.qi_required(p, data))],
	]
	_status.text = "\n".join(lines)
	_status.text += "\n" + "\n".join(PackedStringArray([
		"Alignment: %s (%d)" % [Alignment.tier_name(p.alignment, data), p.alignment],
		Sects.describe(p, data),
		"Spirit Stones: %d" % p.item_count("spirit_stone"),
		GameClock.date_string(),
	]))
	var density := Exploration.qi_density(data, GameState.current_region)
	_status.text += "\n%s   (Qi x%s)" % [Exploration.region_name(data, GameState.current_region), String.num(density, 2)]
	_qi_bar.max_value = maxf(Cultivation.qi_required(p, data), 1.0)
	_qi_bar.value = p.qi
	_bottleneck.text = bottleneck_hint(p, data)
	_bottleneck.visible = _bottleneck.text != ""
	_qi_bar.modulate = UIStyle.ACCENT if _bottleneck.visible else Color.WHITE
	_injuries.visible = Injuries.has_any(p)
	_injuries.text = "Injured: " + ", ".join(Injuries.describe(p, data))
	var hints := Guidance.hints(p, data, density * Sects.cultivation_bonus(p, data), 1)
	_hint.visible = bool(Settings.get_value("show_hints")) and not hints.is_empty()
	_hint.text = "Next: " + hints[0] if not hints.is_empty() else ""


## Message category for the age line: "danger" or "warning" when little of
## the lifespan is left, "" otherwise.
static func lifespan_category(years_left: int, lifespan: int) -> String:
	var fraction := float(years_left) / maxf(float(lifespan), 1.0)
	if years_left <= 3 or fraction <= LIFESPAN_DANGER:
		return "danger"
	if fraction <= LIFESPAN_WARNING:
		return "warning"
	return ""


## Hint under the qi bar once the character must break through ("" = none).
static func bottleneck_hint(c: CharacterData, data: GameData) -> String:
	if Cultivation.can_attempt_breakthrough(c, data):
		return "Bottleneck! Attempt a breakthrough at a meditation spot (%d%% chance)." % int(Cultivation.breakthrough_chance(c, data) * 100)
	if Cultivation.is_at_bottleneck(c, data):
		return "You stand at the peak of the known realms."
	return ""


func _on_message(text: String, category: String) -> void:
	var color: Color = UIStyle.CATEGORY_COLORS.get(category, Color.WHITE)
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	if _log.get_paragraph_count() > MAX_LOG_LINES:
		_log.remove_paragraph(0)


func _on_target_changed(display_name: String) -> void:
	_prompt.text = "[E] %s" % display_name if display_name != "" else ""


func _on_menu_requested(source: Node) -> void:
	if _any_screen_open() or _dialogue.visible or _encounter.visible or _combat_report.visible or _respawn.visible or _pause_menu.visible or _settings.visible or _help.visible or _load_screen.visible or _death_screen.visible:
		return
	_choice_menu.open_for(source)
	_update_modal()


func _on_player_died(cause: String) -> void:
	_choice_menu.close()
	_close_screens()
	_combat_report.close()
	_respawn.close()
	_dialogue.close()
	_encounter.close()
	_pause_menu.close()
	_settings.close()
	_help.close()
	_load_screen.close()
	(_death_screen.find_child("Cause", true, false) as Label).text = cause
	_death_screen.visible = true
	_death_screen.find_children("*", "Button", true, false)[0].grab_focus()
	_update_modal()


## Fights can start from an interaction menu or a random encounter; either
## way, take over the screen with the full report.
func _on_combat_finished(enemy_name: String, victory: bool, lines: PackedStringArray) -> void:
	_choice_menu.close()
	_close_screens()
	_combat_report.show_fight(enemy_name, victory, lines)
	_update_modal()


## The artifact saved the player: once the fight report is read, let them
## choose which anchor to awaken at.
func _open_pending_respawn() -> void:
	if GameState.pending_respawn.is_empty() or _combat_report.visible or _death_screen.visible:
		return
	_choice_menu.close()
	_close_screens()
	_respawn.open()
	_update_modal()


## Talking to an NPC (usually from its choice menu) opens the conversation.
func _on_dialogue_requested(_npc_id: String) -> void:
	_choice_menu.close()
	_close_screens()
	_dialogue.open()
	_update_modal()


## An explored encounter asks the player to choose (help, rob, fight...).
func _on_encounter_choice_requested(_encounter_id: String) -> void:
	_choice_menu.close()
	_close_screens()
	_encounter.open()
	_update_modal()


func _on_breakthrough(success: bool, realm_name: String) -> void:
	if success:
		_banner.announce("Breakthrough!", "You have entered the %s realm." % realm_name, UIStyle.ACCENT)
	else:
		_banner.announce("Breakthrough Failed", "Your qi scatters before the gate of %s." % realm_name, UIStyle.CATEGORY_COLORS["danger"])


## Settings replaces the pause menu while open, then returns to it.
func _open_settings() -> void:
	_pause_menu.visible = false
	_settings.open()


## Help replaces the pause menu while open, then returns to it.
func _open_help() -> void:
	_pause_menu.visible = false
	_help.open()


## Load replaces the pause menu while open, then returns to it.
func _open_load() -> void:
	_pause_menu.visible = false
	_load_screen.open()


func _on_load_closed() -> void:
	if GameState.has_session() and GameState.player.alive:
		_pause_menu.open()
	_update_modal()


func _on_slot_chosen(slot: String) -> void:
	if SaveManager.load_game(slot):
		get_tree().reload_current_scene()
	else:
		_load_screen.open()


func _on_settings_closed() -> void:
	if GameState.has_session() and GameState.player.alive:
		_pause_menu.open()
	_update_modal()


func _update_modal() -> void:
	EventBus.ui_modal_changed.emit(_choice_menu.visible or _dialogue.visible or _encounter.visible or _any_screen_open() or _combat_report.visible or _respawn.visible or _pause_menu.visible or _settings.visible or _help.visible or _load_screen.visible or _death_screen.visible)


func _return_to_menu() -> void:
	GameState.end_session()
	get_tree().change_scene_to_file(MAIN_MENU)
