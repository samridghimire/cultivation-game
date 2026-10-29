extends CanvasLayer
## In-game overlay: status panel, message log, interaction prompt, and modal
## windows (choice menu, toggleable screens, death screen).

const MAIN_MENU := "res://src/ui/main_menu.tscn"
const MAX_LOG_LINES := 60
const LOG_HEIGHT := 108.0  ## Space the log panel takes at the bottom (offset 108 in _build_log).
const LOG_IDLE_SECONDS := 8.0  ## GFX-010: the log fades after this long without a message.
const LOG_IDLE_ALPHA := 0.55
const HINT_MAX_CHARS := 120  ## WU-305: a status-panel hint line is cut past this (about three wrapped lines).
const STATUS_MARGIN := 8.0  ## Gap kept between the status panel and the log.
## Lifespan cue thresholds (fraction of the lifespan left).
const LIFESPAN_WARNING := 0.15
const LIFESPAN_DANGER := 0.05

## The hint lines changed (WU-280: the world marks the place the first one names).
signal hints_changed

var _age: Label
var _breakthrough_details: String = ""
var _status: Label
var _lives: Label
var _qi_bar: ProgressBar
var _bottleneck: Label
var _next_layer: Label
var _injuries: Label
var _hint: Label
var _lives_badge: Label  # WU-340: the same gold "!" beside the Lives label while the first hint is the artifact lives line
var _hint_badge: Label  # WU-284: gold "!" over the first hint when it names a place here
var _hint_lines: PackedStringArray = []
var _goal: Label
var _hunt: Label
var _fair: Label
var _fair_queued := false
var _log: RichTextLabel
var _last_text: String = ""
var _last_category: String = ""
var _repeat: int = 0
var _log_lines: Array[String] = []  ## BBCode of each HUD log line, for collapsing repeats.
var _status_panel: Control
var _log_panel: Control
var _fade_timer := 0.0
var _fade_targets := Vector3.ONE  # status, log, guide
var _guide_panel: Control
var _realm: Label
var _qi_text: Label
var _currency: Label
var _last_message_msec := 0
var _prompt: Label
var _key_bar: Label
var _target_name := ""

## [action, caption] pairs shown in the key bar.
const KEY_HINTS := [
	["interact", "interact"], ["toggle_character_sheet", "character"], ["toggle_inventory", "inventory"],
	["toggle_techniques", "techniques"], ["toggle_map", "map"], ["toggle_message_log", "log"],
	["toggle_artifact", "artifact"], ["toggle_clan", "clan"], ["toggle_family", "family"], ["toggle_journal", "journal"], ["quick_save", "save"], ["quick_load", "load"], ["pause_menu", "pause"], ["toggle_help", "help"],
]
var _choice_menu: ChoiceMenu
var _threat_prompt: ThreatPrompt
## Toggleable modal screens keyed by the input action that opens them. Each
## must have open(), close() and a `closed` signal.
var _screens: Dictionary = {}
var _combat_report: CombatReport
var _fight_rating: String = ""
var _fight_enemy: Dictionary = {}
var _dialogue: DialogueWindow
var _encounter: EncounterWindow
var _arrival_waiting: String = ""  # arrival card held back while a road encounter window is open (WU-080)
var _pause_menu: PauseMenu
var _settings: SettingsScreen
var _load_screen: LoadScreen
var _help: HelpScreen
var _help_from_key := false
var _crafting: CraftingScreen
var _shop: ShopScreen
var _mission_board: MissionBoard
var _auction: AuctionScreen
var _sect_balance: SectBalanceWindow
var _gossip: GossipWindow
var _family: FamilyScreen
var _child_training: ChildTrainingScreen
var _banner: Banner
var _tech_levels: Dictionary = {}  # technique id -> last seen level (WU-130)
var _goals_done: Array[String] = []  # texts of first goals already done (WU-131)
var _goals_ladder: String = ""  # Guidance.goal_ladder_id when _goals_done was taken
var _season := ""
var _season_flush_queued := false
var _time_skip: TimeSkipOverlay
var _pending_year: Array = []  # [year, lines, start_year] waiting for a free screen (WU-031)
## The time-skip summary on screen, kept across the scene reload that travel
## triggers so the new HUD can finish showing it ({} = none).
static var _showing_skip: Dictionary = {}
var _respawn: RespawnScreen
var _realm_card: RealmCard
## [frame, text] of recent feature notices, so a realm card can list the ones its breakthrough caused.
var _recent_notices: Array = []
## [realm name, description, details, notices] of a realm card waiting for the tribulation screen to close ([] = none).
var _pending_realm_card: Array = []
var _tribulation: TribulationScreen
var _breakthrough: BreakthroughScreen
var _death_screen: Control


func _ready() -> void:
	_build_status_panel()
	_build_log()
	_prompt = UIStyle.label("", 18, UIStyle.ACCENT)
	_set_anchored_rect(_prompt, Vector4(0.5, 1, 0.5, 1), Vector4(-300, -170, 300, -132))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	_refresh_key_hints()

	_choice_menu = ChoiceMenu.new()
	_choice_menu.closed.connect(_update_modal)
	add_child(UIStyle.centered(_choice_menu))
	_threat_prompt = ThreatPrompt.new()
	add_child(_threat_prompt)
	_add_screen("toggle_character_sheet", CharacterSheet.new())
	_add_screen("toggle_inventory", InventoryScreen.new())
	_add_screen("toggle_techniques", TechniquesScreen.new())
	_add_screen("toggle_artifact", ArtifactScreen.new())
	_add_screen("toggle_map", WorldMapScreen.new())
	_add_screen("toggle_message_log", MessageLogScreen.new())
	_add_screen("toggle_clan", ClanScreen.new())
	_add_screen("toggle_journal", JournalScreen.new())
	_crafting = CraftingScreen.new()
	_crafting.closed.connect(_update_modal)
	add_child(UIStyle.centered(_crafting))
	_shop = ShopScreen.new()
	_shop.closed.connect(_update_modal)
	add_child(UIStyle.centered(_shop))
	_mission_board = MissionBoard.new()
	_mission_board.closed.connect(_update_modal)
	add_child(UIStyle.centered(_mission_board))
	_auction = AuctionScreen.new()
	_auction.closed.connect(_update_modal)
	add_child(UIStyle.centered(_auction))
	_sect_balance = SectBalanceWindow.new()
	_sect_balance.closed.connect(_update_modal)
	add_child(UIStyle.centered(_sect_balance))
	_gossip = GossipWindow.new()
	_gossip.closed.connect(_update_modal)
	add_child(UIStyle.centered(_gossip))
	_family = FamilyScreen.new()
	_add_screen("toggle_family", _family)
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
	_encounter.closed.connect(_show_waiting_arrival)
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
	_help.closed.connect(_on_help_closed)
	add_child(UIStyle.centered(_help))
	_pause_menu.help_requested.connect(_open_help)
	_pause_menu.journal_requested.connect(_open_journal)
	_respawn = RespawnScreen.new()
	_respawn.closed.connect(_update_modal)
	_respawn.closed.connect(_flush_year_review)
	add_child(UIStyle.centered(_respawn))
	_combat_report.closed.connect(_open_pending_respawn)
	_tribulation = TribulationScreen.new()
	_tribulation.closed.connect(_update_modal)
	_tribulation.closed.connect(_open_pending_respawn)
	_tribulation.closed.connect(_open_pending_realm_card)
	add_child(UIStyle.centered(_tribulation))
	_breakthrough = BreakthroughScreen.new()
	_breakthrough.closed.connect(_update_modal)
	add_child(UIStyle.centered(_breakthrough))
	_realm_card = RealmCard.new()
	_realm_card.closed.connect(_update_modal)
	add_child(UIStyle.centered(_realm_card))
	_banner = Banner.new()
	add_child(_banner)
	add_child(SaveToast.new())
	_time_skip = TimeSkipOverlay.new()
	_time_skip.closed.connect(_on_time_skip_closed)
	add_child(_time_skip)
	_build_death_screen()
	_show_load_recap()

	EventBus.player_changed.connect(_refresh)
	EventBus.session_started.connect(_refresh)
	EventBus.player_changed.connect(_queue_fair_fight)
	EventBus.session_started.connect(_queue_fair_fight)
	EventBus.region_changed.connect(func(_id): _queue_fair_fight())
	GameClock.days_advanced.connect(func(_d): _queue_fair_fight())
	EventBus.region_changed.connect(func(_id): _refresh())
	EventBus.region_changed.connect(_on_arrival)
	EventBus.message_posted.connect(_on_message)
	Settings.changed.connect(_on_setting_changed)
	EventBus.interaction_target_changed.connect(_on_target_changed)
	InputConfig.controls_changed.connect(_refresh_key_hints)
	EventBus.interaction_menu_requested.connect(_on_menu_requested)
	EventBus.crafting_requested.connect(_on_crafting_requested)
	EventBus.shop_requested.connect(_on_shop_requested)
	EventBus.mission_board_requested.connect(_on_mission_board_requested)
	EventBus.auction_requested.connect(_on_auction_requested)
	EventBus.sect_balance_requested.connect(_on_sect_balance_requested)
	EventBus.gossip_requested.connect(_on_gossip_requested)
	EventBus.family_requested.connect(_on_family_requested)
	EventBus.child_training_requested.connect(_on_child_training_requested)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(func(_anchor_id: String, _lives: int): _refresh(); _open_pending_respawn())
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_finished.connect(_on_combat_finished)
	EventBus.tribulation_prepare_requested.connect(_on_tribulation_prepare)
	EventBus.breakthrough_prepare_requested.connect(_on_breakthrough_prepare)
	EventBus.tribulation_endured.connect(_on_tribulation_endured)
	EventBus.breakthrough_details.connect(func(text: String) -> void: _breakthrough_details = text)
	EventBus.breakthrough_attempted.connect(_on_breakthrough)
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.dialogue_ended.connect(func(_id): _dialogue.close())
	EventBus.encounter_choice_requested.connect(_on_encounter_choice_requested)
	EventBus.encounter_choice_resolved.connect(_encounter.close)
	EventBus.threat_sensed.connect(_on_threat_sensed)
	EventBus.time_skipped.connect(_on_time_skipped)
	EventBus.year_reviewed.connect(_on_year_reviewed)
	EventBus.milestone_reached.connect(_on_milestone)
	EventBus.feature_unlocked.connect(_on_feature_unlocked)
	EventBus.festival_started.connect(_on_festival_started)
	EventBus.bounty_claimed.connect(_on_bounty_claimed)
	EventBus.letter_arrived.connect(_on_letter_arrived)
	EventBus.secret_realm_notice.connect(_on_secret_realm_notice)
	EventBus.renown_tier_reached.connect(_on_renown_tier_reached)
	EventBus.region_mastered.connect(_on_region_mastered)
	EventBus.session_started.connect(_sync_tech_levels)
	EventBus.player_changed.connect(_announce_tech_levels)
	_sync_tech_levels()
	EventBus.session_started.connect(_sync_goals_done)
	EventBus.player_changed.connect(_announce_goals_done)
	_sync_goals_done()
	_season = Calendar.season_of(GameClock.total_days)
	GameClock.days_advanced.connect(_on_days_advanced)
	EventBus.session_started.connect(func(): _season = Calendar.season_of(GameClock.total_days))
	_refresh()
	_refresh_fair_fight()
	# A respawn that moved the player reloads the world; ask where to awaken now.
	_open_pending_respawn.call_deferred()
	# A fresh character opens with the artifact's intro event (ART-006b).
	GameState.start_pending_event.call_deferred()
	if not _showing_skip.is_empty():
		_show_time_skip.call_deferred(_showing_skip)


func _unhandled_input(event: InputEvent) -> void:
	if _choice_menu.visible or _dialogue.visible or _encounter.visible or _combat_report.visible or _tribulation.visible or _respawn.visible or _realm_card.visible or _pause_menu.visible or _settings.visible or _help.visible or _load_screen.visible or _death_screen.visible:
		return
	if event.is_action_pressed("pause_menu"):
		# Consumed here so the world's own Esc handling never runs mid-session.
		get_viewport().set_input_as_handled()
		_close_screens()
		_pause_menu.open()
		_update_modal()
		return
	if event.is_action_pressed("toggle_help"):
		get_viewport().set_input_as_handled()
		_close_screens()
		_help_from_key = true
		_help.open()
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
	_breakthrough.close()
	_crafting.close()
	_shop.close()
	_mission_board.close()
	_auction.close()
	_sect_balance.close()
	_gossip.close()
	_child_training.close()


func _on_crafting_requested(prof_id: String) -> void:
	_crafting.open(prof_id)
	_update_modal()


func _on_shop_requested(merchant_name: String, max_price: int, stock_tags: Array, faction: String, buy_tags: Array) -> void:
	_shop.open(merchant_name, max_price, stock_tags, faction, buy_tags)
	_update_modal()


func _on_mission_board_requested() -> void:
	_mission_board.open()
	_update_modal()


func _on_sect_balance_requested() -> void:
	_sect_balance.open()
	_update_modal()


func _on_gossip_requested(lines: PackedStringArray) -> void:
	_gossip.open(lines)
	_update_modal()


func _on_auction_requested(house_id: String) -> void:
	_auction.open(house_id)
	_update_modal()


func _on_family_requested() -> void:
	_close_screens()
	_family.open()
	_update_modal()


func _on_child_training_requested() -> void:
	_close_screens()
	_child_training.open()
	_update_modal()


func _any_screen_open() -> bool:
	return _breakthrough.visible or _crafting.visible or _shop.visible or _mission_board.visible or _auction.visible or _sect_balance.visible or _gossip.visible or _child_training.visible or _screens.values().any(func(s): return s.visible)


func _build_status_panel() -> void:
	var panel := UIStyle.panel(Vector2(316, 0))
	_status_panel = panel
	panel.position = Vector2(16, 16)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_age = UIStyle.label("", 15)
	box.add_child(_age)
	_realm = UIStyle.label("", 15, UIStyle.ACCENT)
	box.add_child(_realm)
	_qi_bar = ProgressBar.new()
	_qi_bar.custom_minimum_size = Vector2(300, 16)
	_qi_bar.show_percentage = false
	box.add_child(_qi_bar)
	_qi_text = UIStyle.label("", 12)
	_qi_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qi_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_qi_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_qi_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qi_bar.add_child(_qi_text)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 16)
	box.add_child(money_row)
	_lives = UIStyle.label("", 15)
	money_row.add_child(_lives)
	_lives_badge = UIStyle.label("!", 15, UIStyle.ACCENT)
	_lives_badge.visible = false
	_lives.add_child(_lives_badge)
	_currency = UIStyle.label("", 15)
	money_row.add_child(_currency)
	_status = UIStyle.label("", 13, Color(0.75, 0.76, 0.8))
	box.add_child(_status)
	_bottleneck = UIStyle.label("", 14, UIStyle.ACCENT)
	_bottleneck.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_bottleneck)
	_next_layer = UIStyle.label("", 14, Color(0.62, 0.64, 0.7))
	box.add_child(_next_layer)
	_injuries = UIStyle.label("", 14, UIStyle.CATEGORY_COLORS["danger"])
	_injuries.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_injuries)
	add_child(panel)
	_build_guide_panel()


## GFX-010: the "Next steps" card on the top right (goal, hunt, festival fight, hints).
func _build_guide_panel() -> void:
	var panel := UIStyle.panel(Vector2(340, 0))
	_guide_panel = panel
	_set_anchored_rect(panel, Vector4(1, 0, 1, 0), Vector4(-356, 16, -16, 16))
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UIStyle.label("Next steps", 12, Color(0.55, 0.57, 0.63)))
	_goal = UIStyle.label("", 14, Color(0.62, 0.64, 0.7))
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # WU-236: "Goal: Reach Tribulation Transcendence Middle" wraps
	box.add_child(_goal)
	_hunt = UIStyle.label("", 14, UIStyle.ACCENT)
	_hunt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hunt.custom_minimum_size = Vector2(316, 0)
	box.add_child(_hunt)
	_fair = UIStyle.label("", 14, Color("c9b27a"))
	_fair.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fair.custom_minimum_size = Vector2(316, 0)
	box.add_child(_fair)
	_hint = UIStyle.label("", 14, Color("9fd3c7"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(316, 0)
	box.add_child(_hint)
	_hint_badge = UIStyle.label("!", 14, UIStyle.ACCENT)
	_hint_badge.visible = false
	_hint.add_child(_hint_badge)
	add_child(panel)
	_key_bar = UIStyle.label("", 12, Color(0.7, 0.7, 0.7, 0.85))
	_key_bar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_key_bar.custom_minimum_size = Vector2(600, 0)
	_set_anchored_rect(_key_bar, Vector4(1, 1, 1, 1), Vector4(-616, -34, -16, -8))
	_key_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_key_bar.visible = bool(Settings.get_value("key_help"))
	add_child(_key_bar)
	_refresh_key_hints()


func _build_log() -> void:
	var panel := UIStyle.panel()
	_log_panel = panel
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(376, 76)
	_log.add_theme_font_size_override("normal_font_size", 14)
	panel.add_child(_log)
	add_child(panel)
	_set_anchored_rect(panel, Vector4(0, 1, 0, 1), Vector4(16, -108, 416, -16))
	# Seed from the history so the log survives a world reload (travel, respawn).
	var recent: Array = EventBus.history.slice(maxi(0, EventBus.history.size() - MAX_LOG_LINES))
	for e: Dictionary in recent:
		_on_message(String(e.get("text", "")), String(e.get("category", "info")))


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
	var epilogue := UIStyle.label("", 15, Color(0.75, 0.75, 0.75))
	epilogue.name = "Epilogue"
	epilogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(epilogue)
	box.add_child(UIStyle.button("Return to Main Menu", _return_to_menu))
	_death_screen = UIStyle.centered(panel)
	_death_screen.visible = false
	add_child(_death_screen)


## "Spring (4 days left)" within 10 days of the season's end ("Spring (last day)" on it), else just the season (WU-071).
static func season_label(total_days: int) -> String:
	var label := Calendar.season_of(total_days)
	var left := Calendar.days_left_in_season(total_days)
	if left == 0:
		label += " (last day)"
	elif left <= 10:
		label += " (%d day%s left)" % [left, "" if left == 1 else "s"]
	return label


## Banner subtitle: "in <region>." plus up to 2 in-season herbs when there are any.
static func season_banner_subtitle(region: String, highlights: Array[Dictionary]) -> String:
	var sub := "in %s." % region
	if highlights.is_empty():
		return sub
	var parts: Array[String] = []
	for h in highlights.slice(0, 2):
		parts.append("%s at %s" % [h["item_name"], h["place"]])
	return sub + " In season: " + "; ".join(parts) + "."


## "   Beast Tide!" for each world event under way in `region_id` (LW-001b), plus
## " (you can enter)" when `c` can take part in one (WU-005).
static func region_event_suffix(data: GameData, events: Array, region_id: String, c: CharacterData = null) -> String:
	var text := ""
	for instance in WorldEvents.active_in(events, region_id):
		text += "   " + WorldEvents.active_label(data, instance["id"])
		if c != null:
			for kind in ["tournament", "defence"]:
				if WorldEvents.def_of(data, instance["id"]).has(kind) and WorldEvents.check_join(data, events, c, instance["id"], kind, region_id) == "":
					text += " (you can enter)"
					break
	return text


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
	_refresh_lives(p)
	_realm.text = Cultivation.realm_label(p, data)
	_qi_text.text = "Qi: %d / %d" % [int(p.qi), int(Cultivation.qi_required(p, data))]
	_currency.text = currency_line(p)
	_status.text = "\n".join(PackedStringArray([
		"Alignment: %s (%d)" % [Alignment.tier_name(p.alignment, data), p.alignment],
		Sects.describe(p, data),
		"%s · %s · %s" % [GameClock.date_string(), season_label(GameClock.total_days), Weather.label(Weather.of(data, GameState.current_region, GameClock.total_days))],
	]))
	var density := GameState.region_qi_density()
	var qi_why := ", ".join(Exploration.qi_flag_reasons(data, GameState.current_region, GameState.world_flags))
	_status.text += "\n%s   (Qi x%s%s)" % [Exploration.region_name(data, GameState.current_region), String.num(density, 2), ", " + qi_why if qi_why != "" else ""]
	_status.text += region_event_suffix(data, GameState.world_events, GameState.current_region, p)
	if SecretRealms.open_in_region(data, GameState.current_region, GameClock.total_days):
		_status.text += "   (Secret realm open)"
	_qi_bar.max_value = maxf(Cultivation.qi_required(p, data), 1.0)
	_qi_bar.value = p.qi
	_bottleneck.text = bottleneck_hint(p, data)
	_bottleneck.visible = _bottleneck.text != ""
	_qi_bar.modulate = UIStyle.ACCENT if _bottleneck.visible else Color.WHITE
	_next_layer.text = next_layer_text(GameState.days_to_next_stage(density), p, data)
	_next_layer.visible = _next_layer.text != ""
	_injuries.visible = Injuries.has_any(p)
	_injuries.text = "Injured: " + ", ".join(Injuries.describe(p, data))
	var hint_count := int(Settings.get_value("hud_hints"))
	var goal := goal_text(p, data, GameState.world_flags, GameState.clan, density, GameState.current_region, GameClock.total_days) if hint_count > 0 else ""
	_goal.text = goal
	_goal.tooltip_text = goal
	_goal.visible = goal != ""
	var hints: PackedStringArray = []
	if hint_count > 0:
		# GUIDE-031: ask for a few extra so hints that repeat the goal can be dropped without leaving the panel short.
		hints = Guidance.hints(p, data, GameState.hint_density(), hint_count + 2, GameState.npcs, GameState.world_flags, GameState.current_region, GameClock.total_days, GameState.npc_favor)
		hints = Guidance.drop_goal_echoes(goal, hints).slice(0, hint_count)
	var hunt := hunt_line(p, data, GameClock.total_days)
	_hunt.text = hunt
	_hunt.tooltip_text = hunt
	_hunt.visible = hunt != ""
	_hint_lines = hints
	hints_changed.emit()
	_set_hint_text(hints)
	_fit_panels.call_deferred()


func _on_setting_changed(key: String, _v: Variant) -> void:
	if key == "hud_hints":
		_refresh()
		_queue_fair_fight()
	elif key == "key_help":
		_refresh_key_hints()


## Coalesces the signals one action emits (player_changed, days_advanced...) into one recompute per frame.
func _queue_fair_fight() -> void:
	if _fair_queued:
		return
	_fair_queued = true
	_refresh_fair_fight.call_deferred()


## "Fair fight: ..." (WU-125). Guidance.fair_fights runs combat sims, so it is recomputed only on these
## refresh signals, never per frame. Hidden when hints are off or nothing is fair.
func _refresh_fair_fight() -> void:
	_fair_queued = false
	if _fair == null:
		return
	var entries: Array = []
	if int(Settings.get_value("hud_hints")) > 0 and GameState.player != null:
		entries = Guidance.fair_fights(GameState.player, GameState.data, GameState.world_flags, GameClock.total_days, GameState.current_region, GameState.npcs, GameState.npc_favor)
	var line := fair_fight_line(entries, _fair.get_theme_font("font"), 14, _fair.custom_minimum_size.x)
	_fair.text = line
	_fair.tooltip_text = "\n".join(entries.map(func(e: Dictionary) -> String: return String(e.get("text", ""))))
	_fair.visible = line != ""
	_fit_panels.call_deferred()


## "Fair fight: <enemy> (<rating> <percent>)" for the best entry ("" for an empty list). Falls back to the entry's
## full text when it names no enemy.
## WU-150: when a font and width are given and the full line would not fit, the percent is dropped first.
static func fair_fight_line(entries: Array, font: Font = null, font_size: int = 14, max_width: float = 0.0) -> String:
	if entries.is_empty():
		return ""
	var best: Dictionary = entries[0]
	var enemy := String(best.get("enemy", ""))
	if enemy == "" or not best.has("chance"):
		return "Fair fight: %s" % String(best.get("text", ""))
	var chance := float(best["chance"])
	var label := Combat.label_for_chance(chance)
	var full := "Fair fight: %s (%s %d)" % [enemy, label, roundi(chance * 100.0)]
	if font != null and max_width > 0.0 and font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		return "Fair fight: %s (%s)" % [enemy, label]
	return full


## WU-340: keeps the gold "!" just right of the Lives text.
func _place_lives_badge() -> void:
	_lives_badge.position = Vector2(_lives.get_minimum_size().x + 6.0, 0.0)


## True when the gold "!" beside the Lives label is showing (WU-340).
func lives_badge_visible() -> bool:
	return _lives_badge.visible and _lives.visible


## "Lives N" from the Creation Artifact (WU-095): warning at 1 life, danger with "Final life" at 0.
func _refresh_lives(p: CharacterData) -> void:
	_lives.text = lives_text(p.artifact_lives)
	_lives.visible = _lives.text != ""
	_lives.add_theme_color_override("font_color", lives_color(p.artifact_lives))
	_place_lives_badge()


static func lives_text(lives: int) -> String:
	if lives < 0:
		return ""
	return "Lives %d" % lives if lives > 0 else "Lives 0 - Final life"


static func lives_color(lives: int) -> Color:
	if lives == 0:
		return UIStyle.CATEGORY_COLORS["danger"]
	return UIStyle.CATEGORY_COLORS["warning"] if lives == 1 else Color.WHITE


## Drops the lowest-priority lines until each card clears the log (WU-091, GFX-010): the status card loses its
## next-layer line, the guide card its festival line, then shrinks the hint, then drops the goal.
func _fit_panels() -> void:
	if _status_panel == null or _guide_panel == null or not is_inside_tree():
		return
	_next_layer.visible = _next_layer.text != ""
	var height := get_viewport().get_visible_rect().size.y - LOG_HEIGHT - 2.0 * STATUS_MARGIN
	var limit := height - _status_panel.position.y
	_status_panel.reset_size()
	if _status_panel.size.y > limit and _next_layer.visible:
		_next_layer.visible = false
		_status_panel.reset_size()
	var glimit := height - _guide_panel.position.y
	for label: Label in [_fair, _hint, _goal]:
		_guide_panel.reset_size()
		if _guide_panel.size.y <= glimit:
			break
		if label == _hint and label.visible and _shrink_hint(glimit):
			break
		if label.visible:
			label.visible = false
	_guide_panel.reset_size()
	_update_guide_visibility()


## The guide card shows only while one of its lines does. With hints off only the hunt line can (an active
## bounty's deadline is state, not a hint, and showed with hints off before GFX-010).
func _update_guide_visibility() -> void:
	var any_line: bool = _goal.visible or _hunt.visible or _fair.visible or _hint.visible
	_guide_panel.visible = any_line and _status_panel.visible


## The first hint line the status panel is showing, "" when none (WU-280).
func first_hint() -> String:
	return _hint_lines[0] if not _hint_lines.is_empty() else ""


func _set_hint_text(lines: PackedStringArray) -> void:
	_hint.visible = not lines.is_empty()
	var marked := not lines.is_empty() and first_hint_names_place(lines[0], _region_place_names())
	_hint_badge.visible = marked
	_lives_badge.visible = not lines.is_empty() and lines[0].begins_with("Your Creation Artifact")
	_place_lives_badge()
	var out: Array = []
	var cut := false
	for i in lines.size():
		out.append(("  " if i == 0 and marked else "> ") + cap_hint(lines[i]))
		cut = cut or cap_hint(lines[i]) != lines[i]
	_hint.text = "\n".join(out)
	# WU-315: mouse hover shows the whole text when a line was cut.
	_hint.tooltip_text = "\n".join(lines) if cut else ""
	_hint.mouse_filter = Control.MOUSE_FILTER_PASS


## Names of the places and NPCs in the current region (what the world marks with its "!" badge).
func _region_place_names() -> Array:
	return Interactable.region_marker_names(GameState.data, GameState.npcs, GameState.current_region, GameState.player)


## True when `hint` names any of `names` (WU-284; the same check the world uses to mark places).
static func first_hint_names_place(hint: String, names: Array) -> bool:
	return not Interactable.hinted_names(hint, names).is_empty()


## WU-257: keeps a shorter hint instead of hiding it. Drops hints from the end down to one, then cuts
## that one to its first sentence. True when the panel fits.
func _shrink_hint(limit: float) -> bool:
	var count := _hint_lines.size()
	while count > 1:
		count -= 1
		_set_hint_text(_hint_lines.slice(0, count))
		_guide_panel.reset_size()
		if _guide_panel.size.y <= limit:
			return true
	if count == 1:
		_set_hint_text(PackedStringArray([first_sentence(_hint_lines[0])]))
		_guide_panel.reset_size()
		if _guide_panel.size.y <= limit:
			return true
	return false


## WU-305: a hint line longer than `max_chars` is cut at a word boundary and ends with "… (J)" (about three wrapped
## lines in the status panel); the journal keeps the full text.
static func cap_hint(text: String, max_chars: int = HINT_MAX_CHARS) -> String:
	if text.length() <= max_chars:
		return text
	var cut := text.substr(0, max_chars)
	var sp := cut.rfind(" ")
	if sp > max_chars / 2:
		cut = cut.substr(0, sp)
	return cut.rstrip(" ,;:.") + "\u2026 (J)"


## The text up to the first ". ", plus " (J)" so the player knows the journal has the rest. Unchanged without one.
static func first_sentence(text: String) -> String:
	var i := text.find(". ")
	if i < 0:
		return text
	return text.substr(0, i + 1) + " (J)"


## "Goal: ..." line: the first unfinished first goal, then the realm goal ladder's next step, then the generic goal ("" = none).
static func goal_text(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData, density: float, region_id: String = "", today: int = -1) -> String:
	if Guidance.first_goals_done(c, data, flags) or c.realm_index >= 2:
		for row in Guidance.active_goal_ladder(c, data, flags, clan):
			if not row["done"]:
				return "Goal: " + str(row["text"])
		var lines := Guidance.goals(c, data, flags, clan, density, region_id, today)
		return "Goal: " + lines[0] if not lines.is_empty() else ""
	for goal in Guidance.first_goals(c, data, flags):
		if not goal["done"]:
			return "Goal: " + str(goal["text"])
	return ""


## "~N days to the next layer here" ("" at a bottleneck, with no qi rate, or beyond ten years).
static func next_layer_text(days: int, c: CharacterData, data: GameData) -> String:
	if days < 0 or days > 3650 or Cultivation.is_at_bottleneck(c, data):
		return ""
	var target := "layer" if data.realms[c.realm_index].id == "qi_refining" else "stage"
	return "~%d %s to the next %s here" % [days, "day" if days == 1 else "days", target]


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


## The log line for a message seen `repeat` times in a row ("text", "text (x2)", ...).
static func collapsed_line(text: String, repeat: int) -> String:
	return text if repeat <= 1 else "%s (x%d)" % [text, repeat]


func _on_message(text: String, category: String) -> void:
	_last_message_msec = Time.get_ticks_msec()
	var color: Color = UIStyle.CATEGORY_COLORS.get(category, Color.WHITE)
	if _repeat > 0 and text == _last_text and category == _last_category and not _log_lines.is_empty():
		_repeat += 1
		_log_lines[-1] = _log_line(color, collapsed_line(text, _repeat))
		# Rewriting the last paragraph in place is unreliable (trailing "\n"); the log is short, so rebuild it.
		_log.clear()
		for line: String in _log_lines:
			_log.append_text(line)
		return
	_repeat = 1
	_last_text = text
	_last_category = category
	var line := _log_line(color, text)
	_log_lines.append(line)
	_log.append_text(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
		_log.remove_paragraph(0)


func _log_line(color: Color, text: String) -> String:
	return "[color=#%s]%s[/color]\n" % [color.to_html(false), text]


func _on_target_changed(display_name: String) -> void:
	_target_name = display_name
	_refresh_key_hints()


## Rebuilds the key bar and the interact prompt from the current bindings.
func _refresh_key_hints() -> void:
	if _key_bar == null or _prompt == null:
		return
	_key_bar.text = InputConfig.key_bar_text(KEY_HINTS)
	_key_bar.visible = bool(Settings.get_value("key_help")) and (_status_panel == null or _status_panel.visible)
	_prompt.text = "[%s] %s" % [InputConfig.current_label("interact"), _target_name] if _target_name != "" else ""
	# A dark backdrop keeps the prompt readable over place labels (WU-087).
	if _target_name != "":
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.05, 0.05, 0.08, 0.8)
		bg.set_content_margin_all(6)
		bg.set_corner_radius_all(4)
		_prompt.add_theme_stylebox_override("normal", bg)
	else:
		_prompt.remove_theme_stylebox_override("normal")


func _on_menu_requested(source: Node) -> void:
	if _any_screen_open() or _dialogue.visible or _encounter.visible or _combat_report.visible or _tribulation.visible or _respawn.visible or _realm_card.visible or _pause_menu.visible or _settings.visible or _help.visible or _load_screen.visible or _death_screen.visible:
		return
	_choice_menu.open_for(source)
	_update_modal()


func _on_player_died(cause: String) -> void:
	_choice_menu.close()
	_close_screens()
	_combat_report.close()
	_respawn.close()
	_tribulation.close()
	_dialogue.close()
	_encounter.close()
	_pause_menu.close()
	_settings.close()
	_help.close()
	_load_screen.close()
	_time_skip.close()
	(_death_screen.find_child("Cause", true, false) as Label).text = cause
	(_death_screen.find_child("Epilogue", true, false) as Label).text = "\n".join(LifeStats.epilogue(GameState.player, GameState.data, GameState.clan, 8, GameState.npcs, GameState.world_flags))
	_death_screen.visible = true
	_death_screen.find_children("*", "Button", true, false)[0].grab_focus()
	_update_modal()


## The rating is read before the fight, while hp and qi are still whole (WU-104).
func _on_combat_started(enemy: Dictionary) -> void:
	_fight_rating = CombatReport.rating_line(GameState.player, GameState.data, enemy)
	_fight_enemy = enemy


## Fights can start from an interaction menu or a random encounter; either
## way, take over the screen with the full report.
func _on_combat_finished(enemy_name: String, victory: bool, lines: PackedStringArray) -> void:
	_choice_menu.close()
	_close_screens()
	_combat_report.show_fight(enemy_name, victory, lines, GameState.last_loss_advice, GameState.last_fight_spoils,
			GameState.last_fight_playback.get("trace", []), int(GameState.last_fight_playback.get("player_max", 0)), int(GameState.last_fight_playback.get("enemy_max", 0)), GameState.last_fight_friendly, _fight_rating,
			str(_fight_enemy.get("id", "")), _fight_enemy.get("tags", []))
	_fight_rating = ""
	_fight_enemy = {}
	_update_modal()


## A breakthrough would bring a Heavenly Tribulation: warn before attempting.
func _on_tribulation_prepare() -> void:
	_choice_menu.close()
	_close_screens()
	_tribulation.open_prepare()
	_update_modal()


## A major breakthrough without a tribulation: show its chance and terms first.
func _on_breakthrough_prepare() -> void:
	_choice_menu.close()
	_close_screens()
	_breakthrough.open()
	_update_modal()


## Play the tribulation's waves; a respawn (if it killed) waits until it closes.
func _on_tribulation_endured(realm_name: String, result: Dictionary) -> void:
	_choice_menu.close()
	_close_screens()
	_tribulation.show_result(realm_name, result)
	_update_modal()


## The artifact saved the player: once the fight report is read, let them
## choose which anchor to awaken at.
func _open_pending_respawn() -> void:
	if GameState.pending_respawn.is_empty() or _combat_report.visible or _tribulation.visible or _death_screen.visible:
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
func _on_threat_sensed(enemy_id: String) -> void:
	_time_skip.close()
	_choice_menu.close()
	_close_screens()
	_threat_prompt.prepare(enemy_id)
	_choice_menu.open_for(_threat_prompt)
	_update_modal()


func _on_encounter_choice_requested(_encounter_id: String) -> void:
	_choice_menu.close()
	_close_screens()
	_encounter.open()
	if GameState.last_explore_discovery:
		Audio.play("chime_progress")
	_update_modal()


## A long action skipped time: show the overlay unless fast skips are on or
## another window (combat report, encounter, death...) has taken the screen.
## Several milestones in one step: each call replaces the banner, so the last one shows (the log lists all).
func _on_milestone(_id: String, milestone_name: String) -> void:
	_banner.announce("Milestone", milestone_name, UIStyle.ACCENT, 1.2)


## A festival started where you stand (WU-072): a festive banner and a chime.
func _on_festival_started(event_name: String, text: String) -> void:
	_banner.announce(event_name, text, UIStyle.CATEGORY_COLORS.get("good", UIStyle.ACCENT), 2.5)
	Audio.play("chime_progress")


## A bounty was paid (WU-082): a banner and a chime.
func _on_bounty_claimed(enemy_name: String, stones: int) -> void:
	var lines := bounty_banner(enemy_name, stones)
	_banner.announce(lines[0], lines[1], UIStyle.CATEGORY_COLORS.get("good", UIStyle.ACCENT), 2.5)
	Audio.play("chime_progress")


## A renown title was earned (WU-084): a banner and a chime.
func _on_renown_tier_reached(region_id: String, title: String) -> void:
	var lines := renown_banner(GameState.data, region_id, title)
	_banner.announce(lines[0], lines[1], UIStyle.ACCENT, 2.5)
	Audio.play("chime_progress")


## [title, subtitle] of the renown banner.
func _sync_tech_levels() -> void:
	_tech_levels.clear()
	if GameState.player == null:
		return
	for tech_id in GameState.player.techniques:
		_tech_levels[tech_id] = Techniques.level(GameState.player, tech_id)


func _announce_tech_levels() -> void:
	var c: CharacterData = GameState.player
	if c == null:
		return
	for entry in leveled_techniques(_tech_levels, c, GameState.data):
		var sub := "Mastered" if entry["mastered"] else ""
		_banner.announce("%s reaches level %d" % [entry["name"], entry["level"]], sub, UIStyle.ACCENT, 1.2, true)
	_sync_tech_levels()


func _done_goal_texts() -> Array[String]:
	var out: Array[String] = []
	if GameState.player == null:
		return out
	for goal in Guidance.goal_ladder(_goals_ladder, GameState.player, GameState.data, GameState.world_flags, GameState.clan):
		if goal["done"]:
			out.append(str(goal["text"]))
	return out


func _sync_goals_done() -> void:
	_goals_ladder = Guidance.goal_ladder_id(GameState.player) if GameState.player != null else ""
	_goals_done = _done_goal_texts()


## A goal of the current ladder ticked off (WU-131, FOUND-004): one banner per refresh, naming the next goal.
## Moving to another ladder (the Foundation breakthrough) only takes a fresh snapshot.
func _announce_goals_done() -> void:
	var c: CharacterData = GameState.player
	if c == null:
		return
	if Guidance.goal_ladder_id(c) == _goals_ladder:
		var goals := Guidance.goal_ladder(_goals_ladder, c, GameState.data, GameState.world_flags, GameState.clan)
		var text := goals_done_banner(_goals_done, goals, _goals_ladder, InputConfig.current_label("toggle_journal"))
		if text != "":
			_banner.announce("Goal done", text, UIStyle.ACCENT, 1.5)
	_sync_goals_done()


## Banner text for the newest goal of `goals` done since `before`, "" when none: the goal, then the next
## one, or once the ladder is complete, a pointer to the journal (`journal_key`).
static func goals_done_banner(before: Array[String], goals: Array[Dictionary], ladder: String, journal_key: String) -> String:
	var fresh := newly_done_goals(before, goals)
	if fresh.is_empty():
		return ""
	var next := "  Your %s goals are done; the journal (%s) has more." % [{"foundation": "Foundation", "core": "Core Formation", "nascent": "Nascent Soul", "soul": "Soul Formation", "void": "Void Refinement", "body": "Body Integration", "mahayana": "Mahayana", "tribulation": "Tribulation Transcendence"}.get(ladder, "first"), journal_key]
	for goal in goals:
		if not goal["done"]:
			next = "  Next: " + str(goal["text"])
			break
	return fresh[-1] + next


## Texts of goals in `goals` that are done but not in `before`, in list order.
static func newly_done_goals(before: Array[String], goals: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for goal in goals:
		var text := str(goal["text"])
		if goal["done"] and not before.has(text):
			out.append(text)
	return out


## Known techniques whose level is above the one in `before`, sorted by name.
## Techniques absent from `before` (just learned) are not reported.
static func leveled_techniques(before: Dictionary, c: CharacterData, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tech_id in c.techniques:
		if not before.has(tech_id):
			continue
		var lvl := Techniques.level(c, tech_id)
		if lvl <= int(before[tech_id]):
			continue
		var def: TechniqueDef = data.techniques.get(tech_id)
		out.append({"name": def.name if def != null else tech_id, "level": lvl, "mastered": Techniques.is_mastered(c, data, tech_id)})
	out.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
	return out


static func renown_banner(data: GameData, region_id: String, title: String) -> PackedStringArray:
	return PackedStringArray([title, "Your name is known in %s" % Exploration.region_name(data, region_id)])


## A region was mastered (WU-090): a banner and a chime.
func _on_region_mastered(region_id: String) -> void:
	var lines := mastery_banner(GameState.data, region_id)
	_banner.announce(lines[0], lines[1], UIStyle.ACCENT, 2.5)
	Audio.play("chime_progress")


## [title, subtitle] of the mastery banner.
static func mastery_banner(data: GameData, region_id: String) -> PackedStringArray:
	return PackedStringArray(["%s mastered" % Exploration.region_name(data, region_id), "You know every path here"])


## A friend's letter arrived (WU-081): a banner and a chime.
func _on_letter_arrived(npc_name: String) -> void:
	var lines := letter_banner(npc_name)
	_banner.announce(lines[0], lines[1], UIStyle.ACCENT, 2.5)
	Audio.play("chime_progress")


## A secret realm will open soon (WU-114): a banner and a chime.
func _on_secret_realm_notice(realm_id: String) -> void:
	var lines := realm_notice_banner(GameState.data, realm_id, GameClock.total_days)
	_banner.announce(lines[0], lines[1], UIStyle.ACCENT, 2.5)
	Audio.play("chime_progress")


## [title, subtitle] of the secret-realm notice banner.
static func realm_notice_banner(data: GameData, realm_id: String, total_days: int) -> PackedStringArray:
	var def: Dictionary = data.secret_realms.get(realm_id, {})
	return PackedStringArray(["%s opens soon" % def.get("name", realm_id), "In about %s" % Calendar.format_duration(SecretRealms.days_until_open(def, total_days))])


## [title, subtitle] of the letter banner.
static func letter_banner(npc_name: String) -> PackedStringArray:
	return PackedStringArray(["A letter", "from %s" % npc_name])


## WU-351: spirit stones, plus the sect contribution a member can still spend.
static func currency_line(p: CharacterData) -> String:
	var line := "Spirit Stones: %d" % p.item_count("spirit_stone")
	if not p.is_rogue():
		line += "   Contribution: %d" % Sects.contribution_balance(p)
	return line


## [title, subtitle] of the bounty-claimed banner.
static func bounty_banner(enemy_name: String, stones: int) -> PackedStringArray:
	return PackedStringArray(["Bounty claimed", "%s: %d spirit stones" % [enemy_name, stones]])


## "Hunting: <enemy> in <region> (N days left)" for the active bounty, "" when none (WU-082).
static func hunt_line(c: CharacterData, data: GameData, today: int) -> String:
	var b := Bounties.active(c, data, today)
	if b.is_empty():
		return ""
	var left := int(b["until_day"]) - today
	var enemy: String = data.enemies.get(String(b["enemy"]), {}).get("name", String(b["enemy"]))
	return "Hunting: %s in %s (%d day%s left)" % [enemy, Exploration.region_name(data, String(b["region"])), left, "" if left == 1 else "s"]


## New-feature notices (WU-042): a banner besides the log line; hidden when hints are off.
func _on_feature_unlocked(text: String) -> void:
	_recent_notices.append([Engine.get_process_frames(), text])
	while _recent_notices.size() > 8:
		_recent_notices.pop_front()
	if int(Settings.get_value("hud_hints")) <= 0:
		return
	_banner.announce("New", text, UIStyle.ACCENT, 2.5)


## The turn of the seasons (WU-062): one low-priority banner for the season you end up in.
func _on_days_advanced(_days: int) -> void:
	var season := Calendar.season_of(GameClock.total_days)
	if season == _season:
		return
	_season = season
	if not _season_flush_queued:
		_season_flush_queued = true
		_flush_season.call_deferred()


func _flush_season() -> void:
	_season_flush_queued = false
	if _time_skip.visible or GameState.player == null or not GameState.player.alive or not GameState.pending_respawn.is_empty():
		return
	var region := Exploration.region_name(GameState.data, GameState.current_region)
	var sub := season_banner_subtitle(region, Exploration.seasonal_highlights(GameState.data, _season))
	_banner.announce("%s arrives" % _season, sub, UIStyle.ACCENT, 1.4, true)
	Audio.play("chime_info")


func _on_time_skipped(days: int, summary: Dictionary) -> void:
	if not TimeSkip.should_show(days, Settings.get_value("fast_time_skips")):
		return
	if _combat_report.visible or _encounter.visible or _dialogue.visible or _respawn.visible or _death_screen.visible:
		return
	_show_time_skip(summary)


func _show_time_skip(summary: Dictionary) -> void:
	_showing_skip = summary
	_time_skip.show_skip(summary)
	_update_modal()


func _on_time_skip_closed() -> void:
	_showing_skip = {}
	_update_modal()
	_flush_year_review()


## Yearly recap (WU-031): queued, then shown by a deferred flush so a time-skip overlay
## that follows the same action goes first; death/respawn screens hold it back.
func _on_year_reviewed(year: int, lines: PackedStringArray, start_year: int = 0) -> void:
	if not Settings.get_value("yearly_recap") or lines.is_empty():
		return
	_pending_year = [year, lines, start_year]
	_flush_year_review.call_deferred()


func _flush_year_review() -> void:
	if _pending_year.is_empty() or _time_skip.visible or _respawn.visible or _death_screen.visible or not GameState.pending_respawn.is_empty():
		return
	if GameState.player == null or not GameState.player.alive:
		return
	var lines: PackedStringArray = _pending_year[1]
	_banner.announce("%s of your journey" % LifeStats.review_title(int(_pending_year[2]), int(_pending_year[0])), "\n".join(lines), UIStyle.ACCENT, 4.0)
	_pending_year = []


## Loaded-save card (WU-025): the recap lines, shown once when the HUD boots after a load.
func _show_load_recap() -> void:
	var lines: PackedStringArray = GameState.load_recap
	GameState.load_recap = []
	if lines.is_empty() or GameState.player == null or not GameState.player.alive or not GameState.pending_respawn.is_empty():
		return
	_banner.announce(lines[0], "\n".join(lines.slice(1)), UIStyle.ACCENT, 4.0)


## Arrival card: region name with qi density and danger, shown on real travel.
func _on_arrival(region_id: String) -> void:
	if GameState.player == null or not GameState.player.alive:
		return # killed on the road with no lives left: the death screen is up
	if not GameState.pending_respawn.is_empty():
		return # the respawn screen is up; the card shows once the player picks where to wake
	if _encounter.visible and GameState.last_travel_road_encounter != "":
		_arrival_waiting = region_id
		return
	_show_arrival(region_id)


func _show_waiting_arrival() -> void:
	var region_id := _arrival_waiting
	_arrival_waiting = ""
	if region_id != "" and GameState.player != null and GameState.player.alive and GameState.pending_respawn.is_empty():
		_show_arrival(region_id)


## Arrival banner subtitle (WU-192): "First visit · Qi x1.5 · Danger: Calm · Known here: Respected".
## `c` may be null (no title).
static func arrival_subtitle(c: CharacterData, data: GameData, region_id: String, qi: float, danger: String, first_visit: bool) -> String:
	var sub := "Qi x%s · Danger: %s" % [String.num(qi, 2), danger]
	if first_visit:
		sub = "First visit · " + sub
	var title := Renown.title(c, data, region_id) if c != null else ""
	if title != "":
		sub += " · Known here: " + title
	return sub


func _show_arrival(region_id: String) -> void:
	var data: GameData = GameState.data
	if data == null or not data.regions.has(region_id):
		return
	var qi := Exploration.qi_density(data, region_id, GameState.world_flags)
	var first_visit := GameState.last_arrival_first_visit
	var sub := arrival_subtitle(GameState.player, data, region_id, qi, WorldMapScreen.danger_name(data, region_id), first_visit)
	var hold := Banner.HOLD_SECONDS * 1.5 if first_visit else 1.0
	_banner.announce(Exploration.region_name(data, region_id), sub, UIStyle.ACCENT, hold)


func _on_breakthrough(success: bool, realm_name: String) -> void:
	var details := _breakthrough_details
	_breakthrough_details = ""
	var surpassed := GameState.last_surpassed_rival
	GameState.last_surpassed_rival = ""
	if success:
		_show_realm_card.call_deferred(realm_name, details, surpassed)
	else:
		_banner.announce("Breakthrough Failed", "Your qi scatters before the gate of %s." % realm_name, UIStyle.CATEGORY_COLORS["danger"])


## The realm card (WU-137), deferred to the end of the frame so the "New" notices the breakthrough
## caused (same frame) are in. Falls back to the banner when the realm has no data.
func _show_realm_card(realm_name: String, details: String, surpassed: String = "") -> void:
	var p := GameState.player
	var data := GameState.data
	if p == null or data == null or p.realm_index >= data.realms.size():
		_banner.announce("Breakthrough!", "You have entered the %s realm." % realm_name, UIStyle.ACCENT)
		return
	var notices: Array = []
	if int(Settings.get_value("hud_hints")) > 0:
		for entry in _recent_notices:
			if int(entry[0]) >= Engine.get_process_frames() - 1:
				notices.append(String(entry[1]))
	_pending_realm_card = [realm_name, data.realms[p.realm_index].description, details, notices, surpassed]
	# After a tribulation, the card waits until its waves have been watched and closed.
	if not _tribulation.visible:
		_open_pending_realm_card()


func _open_pending_realm_card() -> void:
	if _pending_realm_card.is_empty() or _tribulation.visible:
		return
	var card := _pending_realm_card
	_pending_realm_card = []
	_choice_menu.close()
	_close_screens()
	_realm_card.open(card[0], card[1], card[2], card[3], card[4])
	_update_modal()


## Settings replaces the pause menu while open, then returns to it.
func _open_settings() -> void:
	_pause_menu.visible = false
	_settings.open()


## Help replaces the pause menu while open, then returns to it.
func _open_help() -> void:
	_help_from_key = false
	_pause_menu.visible = false
	_help.open()


## The journal opens from the pause menu (no free gamepad button), closing it first.
func _open_journal() -> void:
	_pause_menu.close()
	var journal: Control = _screens["toggle_journal"]
	journal.open()
	_update_modal()


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


## Help opened with its key returns to the world; from the pause menu, back to it.
func _on_help_closed() -> void:
	if _help_from_key:
		_help_from_key = false
		_update_modal()
	else:
		_on_settings_closed()


func _on_settings_closed() -> void:
	if GameState.has_session() and GameState.player.alive:
		_pause_menu.open()
	_update_modal()


## WU-165: 0.35 when any covered screen rect (player, nearby place labels) touches the panel, else 1.0.
static func panel_alpha(panel_rect: Rect2, covered: Array[Rect2]) -> float:
	for r in covered:
		if panel_rect.intersects(r):
			return 0.35
	return 1.0


func _process(delta: float) -> void:
	_fade_timer -= delta
	if _fade_timer <= 0.0:
		_fade_timer = 0.1
		_fade_targets = _compute_fade_targets()
	if _status_panel == null or _log_panel == null:
		return
	var k := minf(1.0, 8.0 * delta)
	var log_target := _fade_targets.y
	var idle := log_idle_alpha(float(Time.get_ticks_msec() - _last_message_msec) / 1000.0)
	if idle < 1.0 and not _log_panel.get_global_rect().has_point(_log_panel.get_global_mouse_position()):
		log_target = minf(log_target, idle)
	_status_panel.modulate.a = lerpf(_status_panel.modulate.a, _fade_targets.x, k)
	_log_panel.modulate.a = lerpf(_log_panel.modulate.a, log_target, k)
	_guide_panel.modulate.a = lerpf(_guide_panel.modulate.a, _fade_targets.z, k)


## GFX-010: the log's target alpha after `seconds_since` seconds without a new message.
static func log_idle_alpha(seconds_since: float) -> float:
	return LOG_IDLE_ALPHA if seconds_since >= LOG_IDLE_SECONDS else 1.0


## Target alphas (status, log, guide). Always 1 while a modal is open or no player is in the world.
func _compute_fade_targets() -> Vector3:
	if _status_panel == null or _log_panel == null or not is_inside_tree() or not _status_panel.visible:
		return Vector3.ONE
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector3.ONE
	var xf := get_viewport().get_canvas_transform()
	var covered: Array[Rect2] = []
	var pp := xf * player.global_position
	covered.append(Rect2(pp - Vector2(20, 25), Vector2(40, 50)))
	var parent := player.get_parent()
	if parent != null:
		for n in parent.get_children():
			var it := n as Interactable
			if it != null and it.global_position.distance_to(player.global_position) < 250.0:
				var lr := it.label_rect()
				covered.append(Rect2(xf * (it.get_parent() as Node2D).to_global(lr.position) if it.get_parent() is Node2D else xf * lr.position, lr.size * xf.get_scale()))
	return Vector3(panel_alpha(_status_panel.get_global_rect(), covered), panel_alpha(_log_panel.get_global_rect(), covered), panel_alpha(_guide_panel.get_global_rect(), covered))


func _update_modal() -> void:
	var blocking := _choice_menu.visible or _dialogue.visible or _encounter.visible or _any_screen_open() or _combat_report.visible or _tribulation.visible or _respawn.visible or _realm_card.visible or _pause_menu.visible or _settings.visible or _help.visible or _load_screen.visible or _death_screen.visible
	# The status panel, hints and log hide behind modals; a time-skip overlay alone keeps them.
	_status_panel.visible = not blocking
	_log_panel.visible = not blocking
	_update_guide_visibility()
	_key_bar.visible = bool(Settings.get_value("key_help")) and not blocking
	EventBus.ui_modal_changed.emit(blocking or _time_skip.visible)
	_hold_banners()


## Banners wait while a report that must be read (fight, respawn, tribulation, death) is up.
func _hold_banners() -> void:
	_banner.set_held(_combat_report.visible or _realm_card.visible or _respawn.visible or _tribulation.visible or _death_screen.visible)


func _return_to_menu() -> void:
	_showing_skip = {}
	GameState.end_session()
	get_tree().change_scene_to_file(MAIN_MENU)
