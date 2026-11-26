extends CanvasLayer
## In-game overlay: status panel, message log, interaction prompt, and modal
## windows (choice menu, toggleable screens, death screen).

const MAIN_MENU := "res://src/ui/main_menu.tscn"
const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const MAX_LOG_LINES := 60
const STATUS_TEXT_WIDTH := 298.0  ## WU-507: fixed text width of the top-left card (316 px panel minus margins).
const MAX_LAMPS := 5  ## GFX-031: soul lamps drawn before "x N".
const QI_FILL := Color("6fd3c1")
const LOG_HEIGHT := 108.0  ## Space the log panel takes at the bottom (offset 108 in _build_log).
const LOG_IDLE_SECONDS := 8.0  ## GFX-010: the log fades after this long without a message.
const LOG_IDLE_ALPHA := 0.55
const HINT_ICON_W := 16  ## WU-471: the icon column left of the hint lines.
const GOAL_W := 316.0  ## The goal row's width (full card).
const HINT_W := 300.0  ## The hint label's width (the card's 316 minus the icon column).
const HINT_MAX_CHARS := 84  ## WU-468: a status-panel hint line is cut past this (about two wrapped lines).
const STATUS_MARGIN := 8.0  ## Gap kept between the status panel and the log.
## Lifespan cue thresholds (fraction of the lifespan left).
const LIFESPAN_WARNING := 0.15
const LIFESPAN_DANGER := 0.05

## The hint lines changed (WU-280: the world marks the place the first one names).
signal hints_changed

var _age: Label
var _breakthrough_details: String = ""
## The frame the breakthrough resolved on while the staged window held the card back (-1 = none), so the
## realm card still lists the "New" notices of that frame (GFX-258 review fix).
var _breakthrough_frame: int = -1
var _status: Label
var _region_name: Label
var _region_chip: Label
var _region_extra: Label
var _lives: HBoxContainer  ## GFX-031: soul lamps plus a Label for "x N" / "Final life".
var _lives_extra: Label
var _stone_icon: TextureRect
var _date_row: HBoxContainer
var _date_label: Label
var _season_icon: TextureRect
var _weather_icon: TextureRect
var _weather_text: Label
var _qi_bar: ProgressBar
var _bottleneck: Label
var _injuries: Label
var _hint: Label
var _lives_badge: Label  # WU-340: the same gold "!" beside the Lives label while the first hint is the artifact lives line
var _hint_icons: Control  # WU-471: the icon column left of the hint label
var _hint_badge: Label  # WU-284: gold "!" over the first hint when it names a place here
var _hint_lines: PackedStringArray = []
var _hint_full := ""  ## GFX-016: the hint text before the line cap.
var _goal: Label
var _hunt: Label
var _fair: Label
var _season_task: Label  ## WU-462: "One more for spring: ..." when one season task is left.
var _fair_queued := false
var _log: RichTextLabel
var _last_text: String = ""
var _last_category: String = ""
var _repeat: int = 0
var _log_truncated := false  ## WU-531: the label shows only the newest messages that fit (or a cut-down newest one)
var _log_ids: Array[int] = []  ## LOG-007: EventBus history id of each HUD log line (parallel to _log_lines).
var _log_lines: Array[String] = []  ## BBCode of each HUD log line, for collapsing repeats.
var _status_panel: Control
var _companion_chip: HBoxContainer  ## WU-413: the friend who fights beside you today.
var _companion_portrait: PortraitBox
var _companion_label: Label
var _log_panel: Control
var _fade_timer := 0.0
var _fade_targets := Vector3.ONE  # status, log, guide
var _key_bar_fade := 1.0  ## WU-472: the key-hint bar's target alpha.
var _guide_panel: Control
var _realm: Label
var _qi_text: Label
var _currency: Label
var _last_message_msec := 0
var _prompt: Label
var _backdrop: ColorRect  ## GFX-017: dims the world behind any open modal.
var _key_bar: Label
var _target_name := ""
var _prompt_floating := false
## Labels keep this many px above the key strip (WU-441).
const KEY_STRIP_CLEARANCE := 28.0

## [action, caption] pairs shown in the key bar.
const KEY_HINTS := [
	["interact", "act"], ["toggle_character_sheet", "sheet"], ["toggle_inventory", "bag"],
	["toggle_techniques", "arts"], ["toggle_map", "map"], ["open_calendar", "cal"],
	["toggle_artifact", "relic"], ["toggle_clan", "clan"], ["toggle_family", "family"], ["toggle_journal", "journal"], ["toggle_help", "help"],
]  # GFX-016: one line at 1280 px; save/load/pause live in the pause menu and the help screen
const GUIDE_MAX_LINES := 5  ## GFX-016: wrapped lines the "Next steps" card may show.
const CARD_FADE_MARGIN := 16.0  ## GFX-016: the player this close to a card fades it.
const CARD_FADE_ALPHA := 0.35
const BACKDROP_ALPHA := 0.45  ## GFX-017
const LOG_CARD_MIN_LINE_PX := 20  ## GFX-017: one log line, in content pixels.
const LOG_CARD_MAX_LINES := 4
const LOG_CARD_PADDING := 24.0  ## the panel's top and bottom margins
var _choice_menu: ChoiceMenu
var _threat_prompt: ThreatPrompt
## Toggleable modal screens keyed by the input action that opens them. Each
## must have open(), close() and a `closed` signal.
var _built_screens: Dictionary = {}
## PERF-031: action -> Callable building that screen (and wiring it) on first use.
var _screen_makers: Dictionary = {}
## Every toggleable screen, built on demand (tests and shots read this; the game itself goes through _screen()).
var _screens: Dictionary:
	get:
		for action: String in _screen_makers:
			_screen(action)
		return _built_screens
var _village_book_n: VillageBook
var _village_book: VillageBook:  # PERF-031: this and the modals below build on first use
	get:
		if _village_book_n == null:
			_village_book_n = VillageBook.new()  # WU-414: no key of its own, opens from the journal
			_village_book_n.closed.connect(_on_book_closed)
			add_child(UIStyle.centered(_village_book_n))
		return _village_book_n
var _book_from: String = ""
var _combat_report: CombatReport
var _fight_rating: String = ""
var _fight_enemy: Dictionary = {}
var _dialogue: DialogueWindow
## The interactable whose menu was opened last: its portrait shows in the dialogue it starts (WU-408).
var _last_source: Node
var _encounter: EncounterWindow
var _quarrel: QuarrelWindow
var _cast_bar: CastBar
var _arrival_title: String = ""  # WU-491: title of the region name card, so a modal can dismiss it
var _arrival_waiting: String = ""  # arrival card held back while a road encounter window is open (WU-080)
var _pause_menu: PauseMenu
var _settings: SettingsScreen
var _load_screen: LoadScreen
var _help: HelpScreen
var _help_from_key := false
var _crafting_n: CraftingScreen
var _crafting: CraftingScreen:
	get:
		if _crafting_n == null:
			_crafting_n = CraftingScreen.new()
			_crafting_n.closed.connect(_update_modal)
			add_child(UIStyle.centered(_crafting_n))
		return _crafting_n
var _shop_n: ShopScreen
var _shop: ShopScreen:
	get:
		if _shop_n == null:
			_shop_n = ShopScreen.new()
			_shop_n.closed.connect(_update_modal)
			add_child(UIStyle.centered(_shop_n))
		return _shop_n
var _mission_board_n: MissionBoard
var _mission_board: MissionBoard:
	get:
		if _mission_board_n == null:
			_mission_board_n = MissionBoard.new()
			_mission_board_n.closed.connect(_update_modal)
			add_child(UIStyle.centered(_mission_board_n))
		return _mission_board_n
var _auction_n: AuctionScreen
var _auction: AuctionScreen:
	get:
		if _auction_n == null:
			_auction_n = AuctionScreen.new()
			_auction_n.closed.connect(_update_modal)
			add_child(UIStyle.centered(_auction_n))
		return _auction_n
var _sect_balance_n: SectBalanceWindow
var _sect_balance: SectBalanceWindow:
	get:
		if _sect_balance_n == null:
			_sect_balance_n = SectBalanceWindow.new()
			_sect_balance_n.closed.connect(_update_modal)
			add_child(UIStyle.centered(_sect_balance_n))
		return _sect_balance_n
var _gossip_n: GossipWindow
var _gossip: GossipWindow:
	get:
		if _gossip_n == null:
			_gossip_n = GossipWindow.new()
			_gossip_n.closed.connect(_update_modal)
			add_child(UIStyle.centered(_gossip_n))
		return _gossip_n
var _child_training_n: ChildTrainingScreen
var _child_training: ChildTrainingScreen:
	get:
		if _child_training_n == null:
			_child_training_n = ChildTrainingScreen.new()
			_child_training_n.closed.connect(_update_modal)
			add_child(UIStyle.centered(_child_training_n))
		return _child_training_n
var _banner: Banner
var _digest_card: DigestCard
## WU-416: the last_digest waiting for a quiet moment to show.
var _digest_pending: Dictionary = {}
## The last_digest already picked up (compared by identity: back-to-back long actions replace it without an empty frame).
var _digest_seen: Dictionary = {}
var _tech_levels: Dictionary = {}  # technique id -> last seen level (WU-130)
var _goals_done: Array[String] = []  # texts of first goals already done (WU-131)
var _goals_ladder: String = ""  # Guidance.goal_ladder_id when _goals_done was taken
var _season := ""
var _season_flush_queued := false
var _time_skip: TimeSkipOverlay
var _gift_left: GiftLeftCard  # WU-600
var _sworn_oath: SwornOath  ## GFX-235
var _trial_return := ""  ## WU-612: "board" or "hall" while the trial card was opened from there
var _trial_stepped := false
var _pending_moments: Array[Dictionary] = []  ## WU-601: friendship moments waiting for a free screen (FIFO)
var _pending_year: Array = []  # [year, lines, start_year] waiting for a free screen (WU-031)
var _pending_kickoff: Array = []  # [season, year, lines] (SEASON-013)
var _pending_season: Array = []  # [season, year, lines] (SEASON-012)
## The time-skip summary on screen, kept across the scene reload that travel
## triggers so the new HUD can finish showing it ({} = none).
static var _showing_skip: Dictionary = {}
static var _skip_player: CharacterData = null  # QA-241: a skip never outlives its session (a freed HUD leaked it into the next one)
var _respawn: RespawnScreen
var _realm_card: RealmCard
var _contest_card: ContestCard  # WU-454
var _friend_card: FriendSceneCard  # WU-467
var _friend_med_card: FriendMeditationCard  # WU-635
var _season_card: SeasonCard  # WU-495
var _sect_card: SectCard  # WU-602
var _trial_card: TrialCard  # WU-609
var _sect_contest_card: SectContestCard  # WU-611
var _contest_return := false
var _pending_friend_scenes: Array = []
var _season_board: SeasonBoard  # WU-466
## [frame, text] of recent feature notices, so a realm card can list the ones its breakthrough caused.
var _recent_notices: Array = []
## [realm name, description, details, notices] of a realm card waiting for the tribulation screen to close ([] = none).
var _pending_realm_card: Array = []
var _tribulation: TribulationScreen
var _breakthrough: BreakthroughScreen
var _death_screen: Control


## [REVIEW] LOG-003: once this HUD is gone no combat report opens, so the log keeps the mission fight intro again.
var _hint_row: HBoxContainer


## WU-557: the hint row follows the hint label's visibility; guarded because both die on exit.
func _sync_hint_row() -> void:
	if is_instance_valid(_hint_row) and is_instance_valid(_hint):
		_hint_row.visible = _hint.visible


func _exit_tree() -> void:
	GameState.combat_report_shown = false


func _ready() -> void:
	_build_status_panel()
	_build_log()
	_prompt = UIStyle.label("", 18, UIStyle.ACCENT)
	_set_anchored_rect(_prompt, Vector4(0.5, 1, 0.5, 1), Vector4(-300, -170, 300, -132))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	_refresh_key_hints()
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, BACKDROP_ALPHA)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	add_child(_backdrop)

	_choice_menu = ChoiceMenu.new()
	_choice_menu.closed.connect(_update_modal)
	add_child(UIStyle.centered(_choice_menu))
	_threat_prompt = ThreatPrompt.new()
	add_child(_threat_prompt)
	_screen_makers["toggle_character_sheet"] = func() -> Control:
		var sheet := CharacterSheet.new()
		sheet.book_requested.connect(_open_village_book.bind("toggle_character_sheet"))
		return sheet
	_screen_makers["toggle_inventory"] = func() -> Control: return InventoryScreen.new()
	_screen_makers["toggle_techniques"] = func() -> Control: return TechniquesScreen.new()
	_screen_makers["toggle_artifact"] = func() -> Control: return ArtifactScreen.new()
	_screen_makers["toggle_map"] = func() -> Control: return WorldMapScreen.new()
	_screen_makers["toggle_message_log"] = func() -> Control: return MessageLogScreen.new()
	_screen_makers["toggle_clan"] = func() -> Control: return ClanScreen.new()
	_screen_makers["toggle_journal"] = func() -> Control:
		var journal := JournalScreen.new()
		journal.book_requested.connect(_open_village_book.bind("toggle_journal"))
		journal.calendar_requested.connect(_open_calendar_from_journal)
		return journal
	_screen_makers["open_calendar"] = func() -> Control: return CalendarScreen.new()  # WU-419
	_screen_makers["toggle_family"] = func() -> Control: return FamilyScreen.new()
	_combat_report = CombatReport.new()
	_combat_report.closed.connect(_update_modal)
	_combat_report.closed.connect(_flush_year_review, CONNECT_DEFERRED)  # WU-495
	add_child(UIStyle.centered(_combat_report))
	_dialogue = DialogueWindow.new()
	_dialogue.closed.connect(_update_modal)
	add_child(UIStyle.centered(_dialogue))
	_encounter = EncounterWindow.new()
	_encounter.closed.connect(_update_modal)
	_encounter.closed.connect(_flush_year_review, CONNECT_DEFERRED)  # WU-495
	_encounter.closed.connect(_show_waiting_arrival)
	add_child(UIStyle.centered(_encounter))
	_quarrel = QuarrelWindow.new()
	_quarrel.closed.connect(_update_modal)
	add_child(UIStyle.centered(_quarrel))
	_cast_bar = CastBar.new()
	_cast_bar.closed.connect(_update_modal)
	add_child(UIStyle.centered(_cast_bar))
	_pause_menu = PauseMenu.new()
	_pause_menu.closed.connect(_update_modal)
	add_child(UIStyle.centered(_pause_menu))
	_pause_menu.settings_requested.connect(_open_settings)
	_pause_menu.load_requested.connect(_open_load)
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
	_tribulation.closed.connect(_flush_year_review, CONNECT_DEFERRED)  # review: the season card waits for the waves
	add_child(UIStyle.centered(_tribulation))
	_breakthrough = BreakthroughScreen.new()
	_breakthrough.closed.connect(_update_modal)
	add_child(UIStyle.centered(_breakthrough))
	_realm_card = RealmCard.new()
	_realm_card.closed.connect(_update_modal)
	_realm_card.closed.connect(_flush_year_review)  # review: a season that turned during a breakthrough waits for the realm card
	add_child(UIStyle.centered(_realm_card))
	_contest_card = ContestCard.new()
	_contest_card.closed.connect(_update_modal)
	_contest_card.closed.connect(_flush_friend_scenes, CONNECT_DEFERRED)  # FOLK-016
	add_child(UIStyle.centered(_contest_card))
	_friend_card = FriendSceneCard.new()
	_friend_card.closed.connect(_update_modal)
	_friend_card.closed.connect(_flush_friend_scenes)
	add_child(UIStyle.centered(_friend_card))
	_friend_med_card = FriendMeditationCard.new()
	_friend_med_card.done.connect(_update_modal)
	add_child(UIStyle.centered(_friend_med_card))
	EventBus.friend_meditation_requested.connect(_on_friend_meditation_requested)
	_season_card = SeasonCard.new()
	_season_card.closed.connect(_update_modal)
	_season_card.closed.connect(_flush_year_review)
	add_child(UIStyle.centered(_season_card))
	_sect_card = SectCard.new()  # WU-602
	_sect_card.closed.connect(_update_modal)
	add_child(UIStyle.centered(_sect_card))
	_trial_card = TrialCard.new()  # WU-609
	_trial_card.closed.connect(_on_trial_card_closed)
	_trial_card.confirmed.connect(_on_trial_confirmed)
	add_child(UIStyle.centered(_trial_card))
	_sect_contest_card = SectContestCard.new()  # WU-611
	_sect_contest_card.closed.connect(_on_sect_contest_card_closed)
	_sect_contest_card.confirmed.connect(_on_sect_contest_confirmed)
	add_child(UIStyle.centered(_sect_contest_card))
	EventBus.promotion_trial_offered.connect(_on_promotion_trial_offered)
	EventBus.promotion_trial_lost.connect(_on_promotion_trial_lost)
	EventBus.sect_contest_offered.connect(_on_sect_contest_offered)
	EventBus.sect_contest_bout.connect(_on_sect_contest_bout)
	EventBus.sect_joined.connect(_on_sect_joined)
	EventBus.sect_promoted.connect(_on_sect_promoted)  # WU-603
	EventBus.sect_lecture_attended.connect(_on_sect_lecture_attended)  # WU-606
	EventBus.technique_leveled.connect(_on_technique_leveled)  # WU-617
	EventBus.sect_reported.connect(_on_sect_reported)  # WU-604
	_friend_card.closed.connect(_flush_year_review)
	_contest_card.closed.connect(_flush_year_review)
	_season_board = SeasonBoard.new()
	_season_board.closed.connect(_update_modal)
	add_child(UIStyle.centered(_season_board))
	EventBus.contest_finished.connect(_on_contest_finished)
	EventBus.friend_scene.connect(_on_friend_scene)
	EventBus.friend_congratulated.connect(_on_friend_congratulated)  # WU-629
	EventBus.friend_tended.connect(_on_friend_tended)
	EventBus.friend_gift_left.connect(_on_friend_gift_left)
	EventBus.lesson_taught.connect(_on_lesson_taught)
	_banner = Banner.new()
	add_child(_banner)
	_digest_card = DigestCard.new()
	_set_anchored_rect(_digest_card, Vector4(0, 1, 0, 1), Vector4(16, -330, 416, -120))
	_digest_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_digest_card)
	add_child(SaveToast.new())
	_time_skip = TimeSkipOverlay.new()
	_time_skip.closed.connect(_on_time_skip_closed)
	add_child(_time_skip)
	_gift_left = GiftLeftCard.new()  # WU-600
	add_child(_gift_left)
	_sworn_oath = SwornOath.new()
	_sworn_oath.visibility_changed.connect(func() -> void: _prompt.visible = not _sworn_oath.visible)  # GFX-236
	_sworn_oath.finished.connect(_update_modal)  # WU-601: the next queued moment plays
	add_child(_sworn_oath)
	_build_death_screen()
	_show_load_recap()
	_show_start_arrival()

	EventBus.player_changed.connect(_refresh)
	EventBus.session_started.connect(_refresh)
	EventBus.player_changed.connect(_queue_fair_fight)
	EventBus.session_started.connect(_queue_fair_fight)
	EventBus.region_changed.connect(_on_region_changed_fair_fight)
	GameClock.days_advanced.connect(_on_days_advanced_fair_fight)
	EventBus.region_changed.connect(_on_region_changed_refresh)
	EventBus.region_changed.connect(_on_arrival)
	EventBus.message_posted.connect(_on_message_posted)
	EventBus.message_replaced.connect(_on_message_replaced)
	EventBus.message_folded.connect(_on_message_folded)
	Settings.changed.connect(_on_setting_changed)
	EventBus.interaction_target_changed.connect(_on_target_changed)
	InputConfig.controls_changed.connect(_refresh_key_hints)
	EventBus.interaction_menu_requested.connect(_on_menu_requested)
	EventBus.crafting_requested.connect(_on_crafting_requested)
	EventBus.shop_requested.connect(_on_shop_requested)
	EventBus.mission_board_requested.connect(_on_mission_board_requested)
	EventBus.season_board_requested.connect(_on_season_board_requested)
	EventBus.auction_requested.connect(_on_auction_requested)
	EventBus.sect_balance_requested.connect(_on_sect_balance_requested)
	EventBus.sect_overview_requested.connect(_on_sect_overview_requested)
	EventBus.gossip_requested.connect(_on_gossip_requested)
	EventBus.family_requested.connect(_on_family_requested)
	EventBus.child_training_requested.connect(_on_child_training_requested)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_finished.connect(_on_combat_finished)
	EventBus.spar_resolved.connect(_on_spar_resolved)  # WU-548
	GameState.combat_report_shown = true  # LOG-003
	EventBus.tribulation_prepare_requested.connect(_on_tribulation_prepare)
	EventBus.breakthrough_prepare_requested.connect(_on_breakthrough_prepare)
	EventBus.tribulation_endured.connect(_on_tribulation_endured)
	EventBus.breakthrough_details.connect(_on_breakthrough_details)
	EventBus.breakthrough_attempted.connect(_on_breakthrough)
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.encounter_choice_requested.connect(_on_encounter_choice_requested)
	EventBus.encounter_choice_resolved.connect(_encounter.close)
	EventBus.quarrel_requested.connect(_on_quarrel_requested)
	EventBus.cast_requested.connect(_on_cast_requested)
	EventBus.threat_sensed.connect(_on_threat_sensed)
	EventBus.time_skipped.connect(_on_time_skipped)
	EventBus.year_reviewed.connect(_on_year_reviewed)
	EventBus.season_reviewed.connect(_on_season_reviewed)
	EventBus.season_began.connect(_on_season_began)
	EventBus.milestone_reached.connect(_on_milestone)
	EventBus.season_tasks_done.connect(_on_season_tasks_done)
	EventBus.feature_unlocked.connect(_on_feature_unlocked)
	EventBus.festival_started.connect(_on_festival_started)
	EventBus.bounty_claimed.connect(_on_bounty_claimed)
	EventBus.letter_arrived.connect(_on_letter_arrived)
	EventBus.friendship_reached.connect(_on_friendship_reached)
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
	EventBus.session_started.connect(_on_session_started_season)
	_refresh()
	_refresh_fair_fight()
	# A respawn that moved the player reloads the world; ask where to awaken now.
	_open_pending_respawn.call_deferred()
	# A fresh character opens with the artifact's intro event (ART-006b).
	GameState.start_pending_event.call_deferred()
	if not _showing_skip.is_empty() and _skip_player == GameState.player:
		_show_time_skip.call_deferred(_showing_skip)


func _unhandled_input(event: InputEvent) -> void:
	if _choice_menu.visible or _dialogue.visible or _encounter.visible or _quarrel.visible or _cast_bar.visible or _combat_report.visible or _tribulation.visible or _respawn.visible or _realm_card.visible or _contest_card.visible or _friend_card.visible or _friend_med_card.visible or _season_card.visible or _sect_card.visible or _trial_card.visible or _sect_contest_card.visible or _season_board.visible or _pause_menu.visible or _up(_settings) or _up(_help) or _up(_load_screen) or _death_screen.visible:
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
		_help_screen().open()
		_update_modal()
		return
	for action: String in _screen_makers:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			var screen: Control = _screen(action)
			if screen.visible:
				screen.close()
			else:
				_close_screens()
				screen.open()
				_update_modal()
			return


## The screen for an input action, built on first use.
func _screen(action: String) -> Control:
	if not _built_screens.has(action):
		var screen: Control = _screen_makers[action].call()
		_built_screens[action] = screen
		screen.closed.connect(_update_modal)
		add_child(UIStyle.centered(screen))
	return _built_screens[action]

## PERF-018: the big rarely-used modals are built on first use, not on every region load.
func _up(c: Control) -> bool:
	return c != null and c.visible


func _settings_screen() -> SettingsScreen:
	if _settings == null:
		_settings = SettingsScreen.new()
		_settings.closed.connect(_on_settings_closed)
		add_child(UIStyle.centered(_settings))
	return _settings


func _help_screen() -> HelpScreen:
	if _help == null:
		_help = HelpScreen.new()
		_help.closed.connect(_on_help_closed)
		add_child(UIStyle.centered(_help))
	return _help


func _load_screen_node() -> LoadScreen:
	if _load_screen == null:
		_load_screen = LoadScreen.new()
		_load_screen.closed.connect(_on_load_closed)
		_load_screen.slot_chosen.connect(_on_slot_chosen)
		add_child(UIStyle.centered(_load_screen))
	return _load_screen



func _close_screens() -> void:
	for screen: Control in _built_screens.values():
		screen.close()
	_book_from = ""
	# PERF-031: only screens that exist can be open.
	for node: Control in [_village_book_n, _crafting_n, _shop_n, _mission_board_n, _auction_n, _sect_balance_n, _gossip_n, _child_training_n]:
		if node != null:
			node.close()
	_breakthrough.close()


func _on_crafting_requested(prof_id: String) -> void:
	_crafting.open(prof_id)
	_update_modal()


func _on_shop_requested(merchant_name: String, max_price: int, stock_tags: Array, faction: String, buy_tags: Array) -> void:
	_shop.open(merchant_name, max_price, stock_tags, faction, buy_tags)
	_update_modal()


func _on_season_board_requested() -> void:
	_close_screens()
	_season_board.open()
	_update_modal()


func _on_mission_board_requested() -> void:
	_mission_board.open()
	_update_modal()


## WU-608: the hall's overview opens the journal's Sect page; closing it returns to the hall menu.
var _overview_from: Node

func _on_sect_overview_requested(source: Node) -> void:
	_overview_from = source
	var journal: Control = _screen("toggle_journal")
	if not journal.closed.is_connected(_on_overview_closed):
		journal.closed.connect(_on_overview_closed, CONNECT_DEFERRED)
	journal.open()
	journal.set_page("sect")
	journal.focus_page()
	_update_modal()


func _on_overview_closed() -> void:
	var src := _overview_from
	_overview_from = null
	if is_instance_valid(src) and not _any_screen_open():
		_choice_menu.open_for(src)


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
	_screen("toggle_family").open()
	_update_modal()


func _on_child_training_requested() -> void:
	_close_screens()
	_child_training.open()
	_update_modal()


func _any_screen_open() -> bool:
	for node: Control in [_crafting_n, _shop_n, _mission_board_n, _auction_n, _sect_balance_n, _gossip_n, _child_training_n, _village_book_n]:
		if _up(node):
			return true
	return _breakthrough.visible or _built_screens.values().any(func(s): return s.visible)


func _build_status_panel() -> void:
	var panel := UIStyle.panel(Vector2(316, 0))
	_status_panel = panel
	var style := UIStyle.panel_style()
	style.set_content_margin_all(8)  # GFX-031: tighter inner margin keeps the card as short as before
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(16, 16)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_age = UIStyle.label("", 14)
	box.add_child(_age)
	_realm = UIStyle.label("", 14, UIStyle.ACCENT)
	box.add_child(_realm)
	_qi_bar = UIStyle.bar(Vector2(300, 16), QI_FILL)
	UIStyle.add_end_cap(_qi_bar)
	box.add_child(_qi_bar)
	_qi_text = UIStyle.label("", 12)
	_qi_text.add_theme_constant_override("outline_size", 3)
	_qi_text.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08))
	_qi_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qi_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_qi_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_qi_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qi_bar.add_child(_qi_text)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 16)
	box.add_child(money_row)
	_lives = HBoxContainer.new()
	_lives.add_theme_constant_override("separation", 2)
	money_row.add_child(_lives)
	_lives_extra = UIStyle.label("", 14)
	_lives.add_child(_lives_extra)
	_lives_badge = UIStyle.label("!", 15, UIStyle.ACCENT)
	_lives_badge.visible = false
	_lives.add_child(_lives_badge)
	var stones := HBoxContainer.new()
	stones.add_theme_constant_override("separation", 4)
	money_row.add_child(stones)
	_stone_icon = TextureRect.new()
	_stone_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stone_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_stone_icon.custom_minimum_size = Vector2(ItemIcon.SIZE * ItemIcon.ZOOM, 0)
	stones.add_child(_stone_icon)
	_currency = UIStyle.label("", 14)
	stones.add_child(_currency)
	_date_row = HBoxContainer.new()
	_date_row.add_theme_constant_override("separation", 6)
	box.add_child(_date_row)
	_date_label = UIStyle.label("", 13, Color(0.75, 0.76, 0.8))
	_date_row.add_child(_date_label)
	_season_icon = _small_icon()
	_date_row.add_child(_season_icon)
	_weather_icon = _small_icon()
	_date_row.add_child(_weather_icon)
	_weather_text = UIStyle.label("", 13, Color(0.75, 0.76, 0.8))
	_date_row.add_child(_weather_text)
	_status = UIStyle.label("", 13, Color(0.75, 0.76, 0.8))
	_status.add_theme_constant_override("line_spacing", -3)
	_status.custom_minimum_size.x = STATUS_TEXT_WIDTH
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_status)
	# WU-507: region name (ellipsis) + a Qi chip on one row, details and the estimate on their own lines.
	var region_row := HBoxContainer.new()
	region_row.add_theme_constant_override("separation", 6)
	box.add_child(region_row)
	_region_name = UIStyle.label("", 13, Color(0.75, 0.76, 0.8))
	_region_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_region_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_row.add_child(_region_name)
	_region_chip = UIStyle.label("", 12)
	region_row.add_child(_region_chip)
	_region_extra = UIStyle.label("", 12, Color(0.75, 0.76, 0.8))
	_region_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_region_extra.custom_minimum_size.x = STATUS_TEXT_WIDTH
	box.add_child(_region_extra)
	box.add_theme_constant_override("separation", 0)
	_bottleneck = UIStyle.label("", 14, UIStyle.ACCENT)
	_bottleneck.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_bottleneck)
	_injuries = UIStyle.label("", 14, UIStyle.CATEGORY_COLORS["danger"])
	_injuries.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_injuries)
	_companion_chip = HBoxContainer.new()
	_companion_chip.name = "CompanionChip"
	_companion_chip.add_theme_constant_override("separation", 6)
	_companion_chip.visible = false
	_companion_portrait = PortraitBox.new(1)
	_companion_chip.add_child(_companion_portrait)
	_companion_label = UIStyle.label("", 13, UIStyle.ACCENT)
	_companion_chip.add_child(_companion_label)
	box.add_child(_companion_chip)
	add_child(panel)
	_build_guide_panel()


## WU-516: gives the region name the width its text needs (capped to the row), so it never shows a cut word without "…".
func _fit_region_name() -> void:
	var font: Font = _region_name.get_theme_font("font")
	var text_w := ceilf(font.get_string_size(_region_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 2.0
	var chip_w := ceilf(_region_chip.get_theme_font("font").get_string_size(_region_chip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + 2.0
	_region_name.custom_minimum_size.x = minf(text_w, STATUS_TEXT_WIDTH - chip_w - 6.0)


func _small_icon() -> TextureRect:
	var t := TextureRect.new()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = Vector2(HudIcons.GLYPH_SIZE, HudIcons.GLYPH_SIZE)
	return t


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
	_goal.custom_minimum_size = Vector2(GOAL_W, 0)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # WU-236: "Goal: Reach Tribulation Transcendence Middle" wraps
	box.add_child(_goal)
	_hunt = UIStyle.label("", 14, UIStyle.ACCENT)
	_hunt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hunt.custom_minimum_size = Vector2(316, 0)
	box.add_child(_hunt)
	_fair = UIStyle.label("", 14, Color("c9b27a"))
	_fair.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # WU-435: the whole line, on two lines when needed
	_fair.custom_minimum_size = Vector2(316, 0)
	box.add_child(_fair)
	_season_task = UIStyle.label("", 14, Color("a8e08a"))
	_season_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_season_task.custom_minimum_size = Vector2(316, 0)
	box.add_child(_season_task)
	_season_task.visible = false
	_hint = UIStyle.label("", 14, Color("9fd3c7"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(HINT_W, 0)
	# WU-471: a 16 px icon column (one 12 px icon per hint line) sits beside the label; the badge overlays its corner.
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 0)
	box.add_child(hint_row)
	_hint_icons = Control.new()
	_hint_icons.custom_minimum_size = Vector2(HINT_ICON_W, 0)
	_hint_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(_hint_icons)
	_hint_badge = UIStyle.label("●", 9, Color("9fd3c7"))  # GFX-017: a real bullet, not a thin "!" that reads as a bar
	_hint_badge.position = Vector2(6, -3)
	_hint_badge.visible = false
	_hint_icons.add_child(_hint_badge)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(_hint)
	_hint_row = hint_row
	_hint.visibility_changed.connect(_sync_hint_row)  # WU-557: a method, not a lambda (its freed capture logged errors on exit)
	add_child(panel)
	_key_bar = UIStyle.label("", 12, Color(0.7, 0.7, 0.7, 0.85))
	_key_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_key_bar.add_theme_stylebox_override("normal", key_bar_style())
	_set_anchored_rect(_key_bar, Vector4(1, 1, 1, 1), Vector4(-640, -34, -16, -8))  # GFX-065: wide enough for 11 hints at 1280 and 720 (it was cut at [C] sheet)
	_key_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_key_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_key_bar.visible = bool(Settings.get_value("key_help"))
	var caps := KeyCaps.new()
	caps.bar = _key_bar
	caps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caps.set_anchors_preset(Control.PRESET_FULL_RECT)
	caps.show_behind_parent = true
	_key_bar.add_child(caps)
	add_child(_key_bar)
	_refresh_key_hints()


func _build_log() -> void:
	var panel := UIStyle.panel()
	_log_panel = panel
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = false  # WU-531: _fit_log_card keeps only whole messages in the label
	_log.custom_minimum_size = Vector2(376, 76)
	_log.add_theme_font_size_override("normal_font_size", 14)
	panel.add_child(_log)
	add_child(panel)
	_set_anchored_rect(panel, Vector4(0, 1, 0, 1), Vector4(16, -108, 416, -16))
	_log.custom_minimum_size.y = LOG_CARD_MIN_LINE_PX
	panel.offset_top = -16.0 - LOG_CARD_MIN_LINE_PX - LOG_CARD_PADDING
	# Seed from the history so the log survives a world reload (travel, respawn).
	var recent: Array = EventBus.history.slice(maxi(0, EventBus.history.size() - MAX_LOG_LINES))
	for e: Dictionary in recent:
		_on_message(String(e.get("text", "")), String(e.get("category", "info")), int(e.get("id", -1)))


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
	_qi_text.text = "Qi %d / %d" % [int(p.qi), int(Cultivation.qi_required(p, data))]
	_currency.text = currency_line(p)
	_stone_icon.texture = ItemIcon.for_id(data, "spirit_stone")
	_stone_icon.visible = _stone_icon.texture != null
	var density := GameState.region_qi_density()
	var qi_why := ", ".join(Exploration.qi_flag_reasons(data, GameState.current_region, GameState.world_flags, GameClock.total_days))
	_refresh_date_row(data)
	_refresh_companion_chip(p)
	_status.text = alignment_line(Alignment.tier_name(p.alignment, data), Sects.describe(p, data))
	_region_chip.text = region_chip_text(density)
	_region_name.text = Exploration.region_name(data, GameState.current_region)
	_fit_region_name()
	_region_chip.add_theme_color_override("font_color", region_chip_color(density))
	var extra := region_event_suffix(data, GameState.world_events, GameState.current_region, p).strip_edges()
	if SecretRealms.open_in_region(data, GameState.current_region, GameClock.total_days):
		extra += "   (Secret realm open)"
	if qi_why != "":
		extra = (qi_why + "   " + extra).strip_edges()
	var estimate := next_stage_short(GameState.days_to_next_stage(density), p, data)
	_region_extra.text = (estimate + "   " + extra).strip_edges()
	_region_extra.visible = _region_extra.text != ""
	_qi_bar.max_value = maxf(Cultivation.qi_required(p, data), 1.0)
	_qi_bar.value = p.qi
	_bottleneck.text = bottleneck_hint(p, data)
	_bottleneck.visible = _bottleneck.text != ""
	UIStyle.set_bar_fill(_qi_bar, UIStyle.ACCENT if _bottleneck.visible else QI_FILL)
	_injuries.visible = Injuries.has_any(p)
	_injuries.text = "Injured: " + ", ".join(Injuries.describe(p, data))
	var hint_count := int(Settings.get_value("hud_hints"))
	var goal := goal_text(p, data, GameState.world_flags, GameState.clan, density, GameState.current_region, GameClock.total_days) if hint_count > 0 else ""
	_goal.text = goal_row(goal, data, _goal.get_theme_font("font"))
	_goal.tooltip_text = goal
	_goal.visible = goal != ""
	var hints: PackedStringArray = []
	if hint_count > 0:
		# GUIDE-031: ask for a few extra so hints that repeat the goal can be dropped without leaving the panel short.
		hints = Guidance.hints(p, data, GameState.hint_density(), hint_count + 2, GameState.npcs, GameState.world_flags, GameState.current_region, GameClock.total_days, GameState.npc_favor, true)
		hints = Guidance.drop_goal_echoes(goal, hints).slice(0, hint_count)
	var hunt := hunt_line(p, data, GameClock.total_days)
	_hunt.text = Guidance.short_fight_line(hunt, data)
	_hunt.tooltip_text = hunt
	_hunt.visible = hunt != ""
	var one_left := season_one_left_line(GameState.season_tasks(), SeasonTasks.season_name(GameClock.total_days)) if hint_count > 0 and SeasonBoard.near_village(data, GameState.current_region) else ""
	_season_task.text = one_left
	_season_task.visible = one_left != ""
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
		entries = Guidance.hud_fight_order(entries)
	var line := fair_fight_line(entries, _fair.get_theme_font("font"), 14, _fair.custom_minimum_size.x)
	_fair.text = one_row_fight_text(Guidance.with_worth(Guidance.short_fight_line(line, GameState.data), entries[0] if not entries.is_empty() else {}), _fair.get_theme_font("font"), 14, _fair.custom_minimum_size.x)  # GUIDE-223: one line; the tooltip keeps the full text
	_fair.tooltip_text = "\n".join(entries.map(func(e: Dictionary) -> String: return String(e.get("text", ""))))
	_fair.visible = line != ""
	_fit_panels.call_deferred()


## WU-571: `text` on one row: when it would wrap at `width`, the " (ask <giver>)" clause goes (the tooltip keeps it).
static func one_row_fight_text(text: String, font: Font, font_size: int, width: float) -> String:
	if font == null or width <= 0.0 or wrapped_lines(text, font, font_size, width).size() <= 1:
		return text
	var re := RegEx.new()
	re.compile(" \\(ask [^)]*\\)")
	return re.sub(text, "")


## "Fair fight: <enemy> (<rating>, <N> in 100)" for the best entry ("" for an empty list). Falls back to the entry's
## full text when it names no enemy.
## WU-435: the line wraps to two lines; the percent is dropped only when two lines are not enough.
static func fair_fight_line(entries: Array, font: Font = null, font_size: int = 14, max_width: float = 0.0) -> String:
	if entries.is_empty():
		return ""
	var best: Dictionary = entries[0]
	var enemy := String(best.get("enemy", ""))
	var prefix := Guidance.fair_fight_prefix(best)
	if enemy == "" or not best.has("chance"):
		return "%s: %s" % [prefix, String(best.get("text", ""))]
	var chance := float(best["chance"])
	var named := String(best.get("short", ""))
	if named == "":
		named = enemy
	# GUIDE-215: the odds once, no rating word after the prefix; "(6 days)" and the odds share one bracket.
	var odds := "%d in 100" % roundi(chance * 100.0)
	var full := "%s: %s (%s)" % [prefix, named, odds]
	if named.ends_with(")"):
		full = "%s: %s, %s)" % [prefix, named.trim_suffix(")"), odds]
	if font != null and max_width > 0.0 and wrapped_lines(full, font, font_size, max_width).size() > 2:
		full = "%s: %s" % [prefix, named]
	return full


## WU-340: keeps the gold "!" just right of the lamps.
func _place_lives_badge() -> void:
	_lives.move_child(_lives_badge, _lives.get_child_count() - 1)


## True when the gold "!" beside the lives lamps is showing (WU-340).
func lives_badge_visible() -> bool:
	return _lives_badge.visible and _lives.visible


## Lamps shown for `lives`: one lit lamp per life up to MAX_LAMPS, one unlit lamp at 0.
static func lamp_count(lives: int) -> int:
	return clampi(lives, 1, MAX_LAMPS)


## "x 2" after the fifth lamp, "Final life" at 0, else "".
static func lives_extra_text(lives: int) -> String:
	if lives == 0:
		return "Final life"
	return "x %d" % (lives - MAX_LAMPS) if lives > MAX_LAMPS else ""


## "Lives N" from the Creation Artifact (WU-095) as soul lamps: warning at 1 life, danger with "Final life" at 0.
## The invited friend's chip: shown only on the day they were asked along (WU-413).
func _refresh_companion_chip(p: CharacterData) -> void:
	var id := Folk.companion_today(p, GameClock.total_days)
	var friend: CharacterData = GameState.npcs.get(id) if id != "" and GameState.npcs != null else null
	_companion_chip.visible = friend != null and friend.alive
	if not _companion_chip.visible:
		return
	_companion_label.text = "%s is with you" % friend.name
	_companion_portrait.set_portrait(PixelFigure.frame(NPC_SCRIPT.look_of(id, Color("9a8f7a")), "down", 0))


func _refresh_lives(p: CharacterData) -> void:
	var lives := p.artifact_lives
	_lives.visible = lives >= 0
	_lives.tooltip_text = lives_text(lives)
	for c in _lives.get_children():
		if c is TextureRect:
			_lives.remove_child(c)
			c.queue_free()
	if lives >= 0:
		for i in lamp_count(lives):
			var lamp := TextureRect.new()
			lamp.texture = HudIcons.lamp(lives > 0)
			lamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			lamp.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			lamp.custom_minimum_size = Vector2(HudIcons.LAMP_SIZE)
			lamp.mouse_filter = Control.MOUSE_FILTER_PASS
			_lives.add_child(lamp)
			_lives.move_child(lamp, i)
	_lives_extra.text = lives_extra_text(lives)
	_lives_extra.add_theme_color_override("font_color", lives_color(lives))
	_place_lives_badge()


## Date, season and weather icons with the full text in the tooltip.
func _refresh_date_row(data: GameData) -> void:
	var kind := Weather.of(data, GameState.current_region, GameClock.total_days)
	var season_name := Calendar.season_of(GameClock.total_days)
	_date_label.text = GameClock.date_string()
	_season_icon.texture = HudIcons.season(season_name)
	_season_icon.visible = _season_icon.texture != null
	_weather_icon.texture = HudIcons.weather(kind)
	_weather_icon.visible = _weather_icon.texture != null
	_weather_text.text = Weather.label(kind) if _weather_icon.texture == null else ""
	_weather_text.visible = _weather_text.text != ""
	var season_text := season_label(GameClock.total_days)
	_season_icon.tooltip_text = season_text
	_date_row.tooltip_text = "%s · %s · %s" % [GameClock.date_string(), season_text, _weather_label(data)]
	_date_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_date_row.mouse_filter = Control.MOUSE_FILTER_PASS


static func lives_text(lives: int) -> String:
	if lives < 0:
		return ""
	return "Lives %d" % lives if lives > 0 else "Lives 0 - Final life"


static func lives_color(lives: int) -> Color:
	if lives == 0:
		return UIStyle.CATEGORY_COLORS["danger"]
	return UIStyle.CATEGORY_COLORS["warning"] if lives == 1 else Color.WHITE


## Screen-space rects of the visible status, Next-steps, log and key-bar panels (GFX-025):
## the world keeps place and NPC labels out from under them.
func occupied_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for c: Control in [_status_panel, _guide_panel, _log_panel, _key_bar]:
		if c != null and c.is_visible_in_tree() and not (c == _log_panel and _log_lines.is_empty()):
			var r := c.get_global_rect()
			if c == _key_bar:
				r = r.grow_side(SIDE_TOP, KEY_STRIP_CLEARANCE)  # WU-441: labels keep off the key strip
			rects.append(r)
	if banner_showing():  # GFX-206: a label never hides behind the announcement ribbon
		rects.append(_banner.ribbon_rect())
	return rects


## GFX-206: whether an announcement banner is on screen (the world re-spreads labels when this flips).
func banner_showing() -> bool:
	return _banner != null and _banner.is_visible_in_tree()


## GFX-069: screen rect of the shown "[E] <name>" chip, an empty Rect2 when there is none.
func current_prompt_rect() -> Rect2:
	if _prompt == null or _prompt.text == "" or not _prompt.is_visible_in_tree():
		return Rect2()
	return _prompt.get_global_rect()


## WU-441: where the "[E] <name>" chip goes: just above the target's name label, else just below it, clamped
## inside `screen` and clear of `avoid` rects whenever a free spot exists (else the clamped spot above).
static func prompt_rect(target_label_rect: Rect2, screen: Rect2, avoid: Array[Rect2], chip_size: Vector2 = Vector2(190, 30), figure: Vector2 = NO_FIGURE) -> Rect2:
	var x := target_label_rect.get_center().x - chip_size.x / 2.0
	var above_y := target_label_rect.position.y - chip_size.y - 2.0
	var below_y := target_label_rect.end.y + 2.0
	var first := Rect2()
	var tries: Array[float] = [above_y, below_y, above_y - chip_size.y - 2.0, below_y + chip_size.y + 2.0]
	for i in tries.size():
		var r := Rect2(Vector2(x, tries[i]), chip_size)
		r.position.x = clampf(r.position.x, screen.position.x, maxf(screen.position.x, screen.end.x - chip_size.x))
		r.position.y = clampf(r.position.y, screen.position.y, maxf(screen.position.y, screen.end.y - chip_size.y))
		if i == 0:
			first = r
		var hit := false
		for a in avoid:
			if r.intersects(a):
				hit = true
				break
		if not hit and _near_figure(r, figure):
			return r
	# WU-475: no free spot by the label: sit just above the figure (may overlap faded labels).
	if figure != NO_FIGURE:
		var r := Rect2(figure + Vector2(-chip_size.x / 2.0, -chip_size.y - 24.0), chip_size)
		r.position.x = clampf(r.position.x, screen.position.x, maxf(screen.position.x, screen.end.x - chip_size.x))
		r.position.y = clampf(r.position.y, screen.position.y, maxf(screen.position.y, screen.end.y - chip_size.y))
		return r
	return first


const NO_FIGURE := Vector2(-1.0e9, -1.0e9)
const PROMPT_MAX_FROM_FIGURE := 120.0


static func _near_figure(chip: Rect2, figure: Vector2) -> bool:
	return figure == NO_FIGURE or chip.get_center().distance_to(figure) <= PROMPT_MAX_FROM_FIGURE


## WU-441: moves the prompt next to its target's label; the bottom-centre spot stays the fallback.
func _place_prompt() -> void:
	if _prompt == null or _target_name == "":
		return
	var player := get_tree().get_first_node_in_group("player")
	var target: Interactable = player.current_target() if player != null and player.has_method("current_target") else null
	var parent := target.get_parent() as CanvasItem if target != null else null
	if target == null or parent == null:
		_prompt_to_bottom()
		return
	var xf := parent.get_global_transform_with_canvas()
	# WU-474: a target whose own label is hidden still gets a chip beside its (virtual) label spot.
	var label_rect: Rect2 = xf * target.label_rect("" if target.label_drawn_ignoring_target() else _target_name)
	var screen := get_viewport().get_visible_rect()
	var chip := _prompt.get_combined_minimum_size()
	var figure: Vector2 = xf * target.position
	if not screen.grow(40.0).has_point(figure):  # WU-475: target off screen
		_prompt_to_bottom()
		return
	var avoid := occupied_rects()
	for stall in get_tree().get_nodes_in_group("festival_stalls"):  # WU-485: the festival caption is a blocker
		var cr: Rect2 = (stall as FestivalStall).caption_screen_rect()
		if cr.size != Vector2.ZERO:
			avoid.append(cr)
	for other: Node in parent.get_children():  # GFX-240: the chip keeps off other places' sprites
		var oi := other as Interactable
		if oi == null or oi == target or oi.is_person():
			continue
		avoid.append(xf * Rect2(oi.position - oi.size / 2.0, oi.size))
	var rect := prompt_rect(label_rect, screen, avoid, chip, figure)
	if _prompt_floating == false:
		_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_prompt_floating = true
	_prompt.position = rect.position
	_prompt.size = chip


## WU-474: the fallback is still a compact chip sized to its text, centred above the bottom HUD.
func _prompt_to_bottom() -> void:
	var chip := _prompt.get_combined_minimum_size()
	var screen := get_viewport().get_visible_rect()
	if not _prompt_floating:
		_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_prompt_floating = true
	_prompt.position = Vector2((screen.size.x - chip.x) / 2.0, screen.end.y - 170.0)
	_prompt.size = chip


## Drops the lowest-priority lines until each card clears the log (WU-091, GFX-010): the status card loses its
## next-layer line, the guide card its festival line, then shrinks the hint, then drops the goal.
func _fit_panels() -> void:
	if _status_panel == null or _guide_panel == null or not is_inside_tree():
		return
	var height := get_viewport().get_visible_rect().size.y - LOG_HEIGHT - 2.0 * STATUS_MARGIN
	var limit := height - _status_panel.position.y
	_status_panel.reset_size()
	var glimit := height - _guide_panel.position.y
	for label: Label in [_season_task, _fair, _hint, _goal]:
		_guide_panel.reset_size()
		if _guide_panel.size.y <= glimit:
			break
		if label == _hint and label.visible and _shrink_hint(glimit):
			break
		if label.visible:
			label.visible = false
	_apply_line_cap()
	_guide_panel.reset_size()
	_update_guide_visibility()


## GFX-016: the card shows at most GUIDE_MAX_LINES wrapped lines; the hint gives up the lines past that.
func _apply_line_cap() -> void:
	_hint.text = _hint_full
	if not _hint.visible:
		return
	var font := _hint.get_theme_font("font")
	var used := 0
	for label: Label in [_goal, _hunt, _fair, _season_task]:
		if label.visible:
			used += maxi(1, wrapped_lines(label.text, font, 14, 316.0).size()) if label != _hunt else 1
	var budget := maxi(1, GUIDE_MAX_LINES - used)
	var cut := cut_entries(_hint_full.split("\n"), font, 14, HINT_W, budget)
	if cut.size() != _hint_full.split("\n").size() or "\n".join(cut) != _hint_full:
		_hint.text = "\n".join(cut)
		_hint.tooltip_text = "\n".join(_hint_lines)  # WU-579: a mouse player can still read the trimmed text
	_sync_hint_icons()


## The guide card shows only while one of its lines does. With hints off only the hunt line can (an active
## bounty's deadline is state, not a hint, and showed with hints off before GFX-010).
func _update_guide_visibility() -> void:
	var any_line: bool = _goal.visible or _hunt.visible or _fair.visible or _season_task.visible or _hint.visible
	_guide_panel.visible = any_line and _status_panel.visible


## The first hint line the status panel is showing, "" when none (WU-280).
func first_hint() -> String:
	return _hint_lines[0] if not _hint_lines.is_empty() else ""


func _set_hint_text(lines: PackedStringArray) -> void:
	if not lines.is_empty():
		GameState.note_buy_hint(lines[0])
	_hint.visible = not lines.is_empty()
	var marked := not lines.is_empty() and first_hint_names_place(lines[0], _region_place_names())
	_hint_badge.visible = marked
	_lives_badge.visible = not lines.is_empty() and lines[0].begins_with("Your Creation Artifact")
	_place_lives_badge()
	var out: Array = []
	var cut := false
	for i in lines.size():
		out.append(cap_hint(lines[i]))
		cut = cut or cap_hint(lines[i]) != lines[i]
	_hint_full = "\n".join(out)
	_hint.text = _hint_full
	# WU-315: mouse hover shows the whole text when a line was cut.
	_hint.tooltip_text = "\n".join(lines) if cut else ""
	_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	_sync_hint_icons()


## WU-471: "goal", "fight", "today", "season" or "other" by the line's prefix. Pure.
static func hint_kind(line: String) -> String:
	var t := line.strip_edges().trim_prefix("> ")
	if t.begins_with("Goal"):
		return "goal"
	if t.begins_with("Easy") or t.begins_with("Fair"):
		return "fight"
	if t.begins_with("Today"):
		return "today"
	if t.begins_with("One more for"):
		return "season"
	return "other"


## WU-471: one 12 px icon per shown hint line, at the line's first wrapped row.
func _sync_hint_icons() -> void:
	if _hint_icons == null:
		return
	for c in _hint_icons.get_children():
		if c != _hint_badge:
			_hint_icons.remove_child(c)
			c.free()
	if not _hint.visible and _hint.text == "":
		return
	var font := _hint.get_theme_font("font")
	var line_h := maxf(font.get_height(14), _hint.get_line_height())
	var y := 0.0
	for e in _hint.text.split("\n"):
		var icon := TextureRect.new()
		icon.texture = HudIcons.hint_glyph(hint_kind(e))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(1, y + (line_h - 12.0) * 0.5)
		icon.size = Vector2(12, 12)
		_hint_icons.add_child(icon)
		y += maxi(1, wrapped_lines(e, font, 14, HINT_W).size()) * line_h


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
	text = short_today(text)
	if text.length() <= max_chars:
		return text
	var cut := text.substr(0, max_chars)
	# WU-468: prefer a clause boundary (", " or ": " or "; "), else a word boundary.
	var best := -1
	for sep in [", ", ": ", "; "]:
		best = maxi(best, cut.rfind(sep))
	if best <= max_chars / 3:
		best = cut.rfind(" ")
	if best > max_chars / 3:
		cut = cut.substr(0, best)
	return cut.rstrip(" ,;:.") + "\u2026 (J)"


## WU-468: "Today in Azure Peak: the Cloud Crane roams, 3 things by the path." -> "Today: the Cloud Crane roams (J)".
## Other lines are unchanged.
static func short_today(text: String) -> String:
	if not text.begins_with("Today in "):
		return text
	var colon := text.find(": ")
	if colon < 0:
		return text
	return "Today: " + Guidance.short_today_item(text.substr(colon + 2)) + " (J)"


## The text up to the first ". ", plus " (J)" so the player knows the journal has the rest. Unchanged without one.
static func first_sentence(text: String) -> String:
	var i := text.find(". ")
	if i < 0:
		return text
	return text.substr(0, i + 1) + " (J)"


## "Goal: ..." line: the first unfinished first goal, then the realm goal ladder's next step, then the generic goal ("" = none).
static func goal_text(c: CharacterData, data: GameData, flags: Dictionary, clan: ClanData, density: float, region_id: String = "", today: int = -1) -> String:
	var text := Guidance.hud_goal_text(c, data, flags, region_id, today, clan, density)
	if text == "":
		return ""
	var note := ""
	if not (Guidance.first_goals_done(c, data, flags) or c.realm_index >= 2):
		note = Guidance.goal_trip_note(c, data, text, region_id)
	return "Goal: " + text + note


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


## LOG-004: the last row was rewritten (a folded repeat): swap it and rebuild the log.
func _on_message_replaced(text: String, category: String) -> void:
	if _log_lines.is_empty():
		return
	_repeat = 1
	_last_text = text
	_last_category = category
	_log_lines[-1] = _log_line(UIStyle.CATEGORY_COLORS.get(category, Color.WHITE), text)
	_log.clear()
	for line: String in _log_lines:
		_log.append_text(line)
	_fit_log_card.call_deferred()


## LOG-005: a practice row moved past dawn lines to the newest position.
func _on_message_folded(text: String, category: String, id: int) -> void:
	var i := _log_ids.find(id)  # LOG-007: by id, since collapsed "(x2)" rows make positions differ from the history
	if i < 0:
		return
	_log_lines.remove_at(i)
	_log_ids.remove_at(i)
	_log_ids.append(id)
	_log_lines.append(_log_line(UIStyle.CATEGORY_COLORS.get(category, Color.WHITE), text))
	_repeat = 1
	_last_text = text
	_last_category = category
	_log.clear()
	for line: String in _log_lines:
		_log.append_text(line)
	_fit_log_card.call_deferred()


func _on_message_posted(text: String, category: String) -> void:
	var id := -1
	if not EventBus.history.is_empty():
		id = int(EventBus.history[-1].get("id", -1))
	_on_message(text, category, id)


func _on_message(text: String, category: String, id: int = -1) -> void:
	_last_message_msec = Time.get_ticks_msec()
	var color: Color = UIStyle.CATEGORY_COLORS.get(category, Color.WHITE)
	if _repeat > 0 and text == _last_text and category == _last_category and not _log_lines.is_empty():
		_repeat += 1
		_log_lines[-1] = _log_line(color, collapsed_line(text, _repeat))
		_log_ids[-1] = id
		# Rewriting the last paragraph in place is unreliable (trailing "\n"); the log is short, so rebuild it.
		_log.clear()
		for line: String in _log_lines:
			_log.append_text(line)
		_fit_log_card.call_deferred()
		return
	_repeat = 1
	_last_text = text
	_last_category = category
	var line := _log_line(color, text)
	_log_lines.append(line)
	_log_ids.append(id)
	if _log_truncated:
		_log_truncated = false
		_log.clear()
		for l: String in _log_lines:
			_log.append_text(l)
	else:
		_log.append_text(line)
	if _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
		_log_ids.pop_front()
		_log.remove_paragraph(0)
	_fit_log_card.call_deferred()


## GFX-017: the content height (px) the log card shows: its text, one to LOG_CARD_MAX_LINES lines.
static func log_card_height(content_px: int) -> float:
	return float(clampi(content_px, LOG_CARD_MIN_LINE_PX, LOG_CARD_MAX_LINES * LOG_CARD_MIN_LINE_PX))


## WU-531: how many of the newest messages (heights in px, oldest first) fit whole in `room` px.
## 0 when even the newest alone is taller than the room.
static func fit_messages(heights: Array[float], room: float) -> int:
	var used := 0.0
	var n := 0
	for i in range(heights.size() - 1, -1, -1):
		used += heights[i]
		if used > room + 0.5:
			break
		n += 1
	return n


## Resizes the log card to its visible lines; the label holds only the newest whole messages that fit.
func _fit_log_card() -> void:
	if _log == null or _log_panel == null:
		return
	if _log_truncated:  # back to the full text before measuring
		_log_truncated = false
		_log.clear()
		for line: String in _log_lines:
			_log.append_text(line)
	var room := float(LOG_CARD_MAX_LINES * LOG_CARD_MIN_LINE_PX)
	var count := _log_lines.size()
	var total := float(_log.get_content_height())
	var offsets: Array[float] = []
	for i in count:
		offsets.append(float(_log.get_paragraph_offset(i)) if i < _log.get_paragraph_count() else total)
	var heights: Array[float] = []
	for i in count:
		var next_y := offsets[i + 1] if i + 1 < count else total
		heights.append(maxf(next_y - offsets[i], 1.0))
	var fit := fit_messages(heights, room)
	if fit == 0 and count > 0:
		# The newest message alone is taller than the card: cut it to the lines that fit, ending in "...".
		_log_truncated = true
		var plain := _log_plain(_log_lines[-1])
		var color: Color = UIStyle.CATEGORY_COLORS.get(_last_category, Color.WHITE)
		var cut := plain.length()
		var shown := plain
		while cut > 8:
			cut -= 6
			shown = plain.substr(0, cut).strip_edges() + "..."
			_log.clear()
			_log.append_text(_log_line(color, shown))
			if float(_log.get_content_height()) <= room + 0.5:
				break
		_log.custom_minimum_size.y = log_card_height(_log.get_content_height())
		_log.scroll_to_line(0)
		_log_panel.offset_top = -16.0 - _log.custom_minimum_size.y - LOG_CARD_PADDING
		_log_panel.size.y = 0.0
		return
	if fit < count:
		# REVIEW (WU-531): show only the messages that fit whole. Scrolling to their offset did not stick in the
		# game (the scroll value is clamped against the card's old height), so the card still opened mid-message.
		_log_truncated = true
		_log.clear()
		for i in range(count - fit, count):
			_log.append_text(_log_lines[i])
	var h := log_card_height(_log.get_content_height())
	_log.custom_minimum_size.y = h
	_log_panel.offset_top = -16.0 - h - LOG_CARD_PADDING
	_log_panel.size.y = 0.0
	_log.scroll_to_line(0)


## The message text of a log line without its BBCode tags.
static func _log_plain(line: String) -> String:
	var re := RegEx.new()
	re.compile("\\[/?[a-z]+(=[^\\]]*)?\\]")
	return re.sub(line, "", true).strip_edges()


func _log_line(color: Color, text: String) -> String:
	return "[color=#%s]%s[/color]\n" % [color.to_html(false), text]


func _on_target_changed(display_name: String) -> void:
	_target_name = display_name
	_refresh_key_hints()
	_place_prompt()  # WU-478: the chip follows its target at once, not at the next modal change


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
	if _any_screen_open() or _dialogue.visible or _encounter.visible or _quarrel.visible or _cast_bar.visible or _combat_report.visible or _tribulation.visible or _respawn.visible or _realm_card.visible or _contest_card.visible or _friend_card.visible or _season_card.visible or _sect_card.visible or _trial_card.visible or _sect_contest_card.visible or _season_board.visible or _pause_menu.visible or _up(_settings) or _up(_help) or _up(_load_screen) or _death_screen.visible:
		return
	_last_source = source
	_choice_menu.open_for(source)
	_update_modal()


## A 0.4 s red vignette over the death screen (WU-397); skipped with reduce_motion.
func _death_vignette() -> void:
	if MotionFx.reduced():
		return
	var veil := ColorRect.new()
	veil.color = Color(0.6, 0.0, 0.0, 0.5)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var tween := veil.create_tween()
	tween.tween_property(veil, "color:a", 0.0, 0.4)
	tween.tween_callback(veil.queue_free)


func _on_player_died(cause: String) -> void:
	_choice_menu.close()
	_close_screens()
	_combat_report.close()
	_respawn.close()
	_tribulation.close()
	_dialogue.close()
	_encounter.close()
	_quarrel.close()
	_cast_bar.close()
	_pause_menu.close()
	if _settings != null:
		_settings.close()
	if _help != null:
		_help.close()
	if _load_screen != null:
		_load_screen.close()
	_time_skip.close()
	(_death_screen.find_child("Cause", true, false) as Label).text = cause
	(_death_screen.find_child("Epilogue", true, false) as Label).text = "\n".join(LifeStats.epilogue(GameState.player, GameState.data, GameState.clan, 8, GameState.npcs, GameState.world_flags))
	_death_screen.visible = true
	_death_vignette()
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
	_combat_report.companion_name = GameState.last_fight_companion
	_combat_report.summary = GameState.last_fight_summary
	_combat_report.show_fight(enemy_name, victory, lines, GameState.last_loss_advice, GameState.last_fight_spoils,
			GameState.last_fight_playback.get("trace", []), int(GameState.last_fight_playback.get("player_max", 0)), int(GameState.last_fight_playback.get("enemy_max", 0)), GameState.last_fight_friendly, _fight_rating,
			str(_fight_enemy.get("id", "")), _fight_enemy.get("tags", []))
	_fight_rating = ""
	_fight_enemy = {}
	_update_modal()


## WU-548: the friendly spar's result block goes under the report.
func _on_spar_resolved(lines: PackedStringArray) -> void:
	_combat_report.show_spar_result(lines)


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


## "Settle the quarrel" in a villager's menu opens the quarrel window (WU-410).
func _on_quarrel_requested(npc_id: String) -> void:
	_choice_menu.close()
	_quarrel.open_for(npc_id)
	_update_modal()


## A pond's Fish option opens the timing bar (WU-412).
func _on_cast_requested(table: Array, days: int, place_name: String) -> void:
	_choice_menu.close()
	_cast_bar.open_for(table, days, place_name)
	_update_modal()


## Talking to an NPC (usually from its choice menu) opens the conversation.
func _on_dialogue_requested(npc_id: String) -> void:
	_choice_menu.close()
	_close_screens()
	var portrait: Texture2D = null
	if npc_id != "" and is_instance_valid(_last_source) and _last_source.has_method("portrait_texture"):  # WU-558: an event has no source
		portrait = _last_source.portrait_texture()
	_dialogue.set_portrait(portrait)
	var header: Dictionary = {}
	if npc_id != "" and is_instance_valid(_last_source) and _last_source.has_method("menu_header"):
		header = _last_source.menu_header()
	_dialogue.set_header(header)
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
## WU-462: "One more for spring: <task>" when exactly one of the season's tasks is left, "" otherwise.
static func season_one_left_line(tasks: Array, season_name: String) -> String:
	var left: Array = tasks.filter(func(t: Dictionary) -> bool: return not bool(t["done"]))
	if tasks.is_empty() or left.size() != 1:
		return ""
	var where := String(left[0].get("where", ""))
	var text := String(left[0]["text"])
	text = SeasonTasks.with_where(text, where)
	return "One more for %s: %s" % [season_name, text]


## WU-462: a banner when the season's set is complete.
func _on_season_tasks_done(season_name: String, reward: String) -> void:
	_banner.announce("The %s tasks are done" % season_name, reward, UIStyle.CATEGORY_COLORS.get("good", UIStyle.ACCENT), 2.5)


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
	for goal in Guidance.goal_ladder(_goals_ladder, GameState.player, GameState.data, GameState.world_flags, GameState.clan, GameClock.total_days):
		if goal["done"]:
			out.append(str(goal["text"]))
	return out


func _sync_goals_done() -> void:
	_goals_ladder = Guidance.goal_ladder_id(GameState.player, GameState.data, GameState.world_flags) if GameState.player != null else ""
	_goals_done = _done_goal_texts()


## A goal of the current ladder ticked off (WU-131, FOUND-004): one banner per refresh, naming the next goal.
## Moving to another ladder (the Foundation breakthrough) only takes a fresh snapshot, except to or from the
## SECT-035 sect ladder: it starts and ends mid-realm, so the goal that flips it is still announced from the old ladder.
func _announce_goals_done() -> void:
	var c: CharacterData = GameState.player
	if c == null:
		return
	var now := Guidance.goal_ladder_id(c, GameState.data, GameState.world_flags)
	if now == _goals_ladder or now == "sect" or _goals_ladder == "sect":
		var goals := Guidance.goal_ladder(_goals_ladder, c, GameState.data, GameState.world_flags, GameState.clan, GameClock.total_days)
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
	var next := "  Your %s goals are done; the journal (%s) has more." % [{"sect": "sect", "foundation": "Foundation", "core": "Core Formation", "nascent": "Nascent Soul", "soul": "Soul Formation", "void": "Void Refinement", "body": "Body Integration", "mahayana": "Mahayana", "tribulation": "Tribulation Transcendence"}.get(ladder, "first"), journal_key]
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


## A villager became a closer friend (WU-418): a banner with their portrait.
func _on_friendship_reached(npc_id: String, text: String) -> void:
	# GFX-235: the top tier gets the staged oath instead of the banner.
	if SwornOath.is_oath_tier(GameState.friendship_hearts(npc_id), GameState.friendship_tier_count()):
		var tiers: Array = GameState.data.family.get("folk_tiers", [])
		var npc: CharacterData = GameState.npcs.get(npc_id)
		if npc != null and not tiers.is_empty():
			if _moments_must_wait():
				_pending_moments.append({"kind": "oath", "npc_id": npc_id})
				return
			_play_oath(npc_id)
			return
	# GFX-227: "<name>: <tier>" with the hearts as its icon; the banner waits behind any time-skip card.
	var tex: Texture2D = HudIcons.hearts(GameState.friendship_tier_count(), GameState.friendship_hearts(npc_id), 3)
	_banner.announce(text, "Your friendship grows", UIStyle.ACCENT, 2.0, false, tex)
	if not friend_on_screen(npc_id):
		_banner.pulse_icon_for(text)  # GFX-233: no hearts to see, so the banner's icon pulses once
	Audio.play("chime_progress")


## WU-601: the Sworn oath at once (the caller has checked nothing is up).
func _play_oath(npc_id: String) -> void:
	var tiers: Array = GameState.data.family.get("folk_tiers", [])
	var npc: CharacterData = GameState.npcs.get(npc_id)
	if npc == null or tiers.is_empty():
		return
	_sworn_oath.begin(npc_id, npc.name, tiers.back())
	Audio.play("chime_progress")


## WU-601: true while a friendship moment must queue (a modal, time-skip card or the oath is up).
func _moments_must_wait() -> bool:
	return _is_blocking() or _time_skip.visible or _sworn_oath.visible


## WU-601: plays the next queued moment once nothing blocks; one at a time, in order.
func _drain_moments() -> void:
	if _pending_moments.is_empty() or _moments_must_wait():
		return
	var m: Dictionary = _pending_moments.pop_front()
	match String(m.get("kind", "")):
		"oath":
			_play_oath(String(m["npc_id"]))
		"tend":
			_play_tend(String(m["npc_id"]), int(m["days_healed"]), String(m.get("line", "")))
		"gift":
			_gift_left.enqueue(String(m["name"]), String(m["item_id"]), int(m["count"]), String(m["line"]))
		"sect_join":
			_play_sect_join(String(m["sect_id"]))
		"sect_report":
			_play_sect_report(String(m["sect_id"]), String(m.get("line", "")), m.get("items", {}))
		"sect_promoted":
			_play_sect_promoted(String(m["sect_id"]), m.get("summary", {}), bool(m.get("has_next", false)))
		"technique_level":
			_play_technique_level(m)
		"sect_lecture":
			_play_sect_lecture(String(m["sect_id"]), m.get("result", {}))
		"trial_lost":
			var lost_sect := String(m["sect_id"])
			_trial_card.open_lost(GameState.data.sects[lost_sect].name, m.get("info", {}), _sect_color(lost_sect))
			_update_modal()
		"trial_return":
			_return_from_trial(String(m.get("to", "")))
		"contest_champion":
			var chs := String(m["sect_id"])
			var heard := GameState.player.folk_news.values().has("contest")
			_sect_contest_card.open_champion(GameState.data.sects[chs].name, SectContestCard.total_prize(GameState.player, GameState.data), heard, _sect_color(chs))
			_update_modal()
		"contest_bout":
			var cs := String(m["sect_id"])
			_sect_contest_card.open_result(GameState.data.sects[cs].name, m.get("info", {}), _sect_color(cs))
			_update_modal()
	if not _pending_moments.is_empty():
		_drain_moments.call_deferred()


## GFX-233: true when the villager `npc_id` is inside the visible screen rect (so their hearts are seen).
func friend_on_screen(npc_id: String) -> bool:
	if not is_inside_tree():
		return false
	var xf := get_viewport().get_canvas_transform()
	var screen := get_viewport().get_visible_rect()
	for n in get_tree().get_nodes_in_group("npc"):
		if n.get("npc_id") == npc_id and n is Node2D:
			return screen.has_point(xf * (n as Node2D).global_position)
	return false


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
	var line := "%d" % p.item_count("spirit_stone")
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
	_banner.announce(notice_title(EventBus.last_notice_id), text, UIStyle.ACCENT, 2.5)


## Banner title for a `Guidance.unlock_notices` id (WU-409).
static func notice_title(notice_id: String) -> String:
	if notice_id.begins_with("road_"):
		return "New road"
	if notice_id.begins_with("promotion_") or notice_id == "clan":
		return "Sect news"
	if notice_id.begins_with("technique_") or notice_id.begins_with("recipe_"):
		return "Learned"
	return "Notice"


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
	if not TimeSkip.should_show(days, Settings.get_value("fast_time_skips"), bool(summary.get("always", false))):
		return
	if _combat_report.visible or _encounter.visible or _quarrel.visible or _cast_bar.visible or _dialogue.visible or _respawn.visible or _death_screen.visible:
		return
	_show_time_skip(summary)


## WU-600: a friend left a gift on arrival: a small card, queued, never pausing time.
func _on_friend_gift_left(npc_id: String, item_id: String, count: int, line: String) -> void:
	var npc: CharacterData = GameState.npcs.get(npc_id)
	var nm: String = npc.name if npc != null else npc_id
	if _moments_must_wait():
		_pending_moments.append({"kind": "gift", "name": nm, "item_id": item_id, "count": count, "line": line})
		return
	_gift_left.enqueue(nm, item_id, count, line)


## WU-599: a Sworn friend tends the player: the tea card pattern, skippable, never pausing time.
func _on_friend_tended(npc_id: String, days_healed: int) -> void:
	if _moments_must_wait() or _encounter.visible:
		# the line is captured now: a second tending on the same arrival overwrites last_tend_line
		_pending_moments.append({"kind": "tend", "npc_id": npc_id, "days_healed": days_healed, "line": GameState.last_tend_line})
		return
	_play_tend(npc_id, days_healed, GameState.last_tend_line)


func _play_tend(npc_id: String, days_healed: int, line: String) -> void:
	var npc: CharacterData = GameState.npcs.get(npc_id)
	_show_time_skip(Folk.tend_card(npc.name if npc != null else npc_id, days_healed, line, npc_id))


func _show_time_skip(summary: Dictionary) -> void:
	_showing_skip = summary
	_skip_player = GameState.player
	_time_skip.show_skip(summary, DayLight.plays_cycle(int(summary.get("days", 0)), MotionFx.reduced(), bool(Settings.get_value("ambient_effects"))))
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


## SEASON-012: the season recap banner; a pending year review wins when both are queued.
func _on_season_reviewed(season: String, year: int, lines: PackedStringArray) -> void:
	if not Settings.get_value("yearly_recap") or lines.is_empty():
		return
	_pending_season = [season, year, lines]
	_flush_year_review.call_deferred()


## SEASON-013: the kickoff banner queues behind the recap (or the year review).
func _on_season_began(season: String, year: int, lines: PackedStringArray) -> void:
	if not Settings.get_value("yearly_recap") or lines.is_empty():
		return
	_pending_kickoff = [season, year, lines]
	_flush_year_review.call_deferred()


func _flush_year_review() -> void:
	_flush_recap_banner()
	if _pending_kickoff.is_empty() and _pending_season.is_empty():
		return
	if not _pending_year.is_empty():
		return
	if _time_skip.visible or _respawn.visible or _death_screen.visible or not GameState.pending_respawn.is_empty():
		return
	if GameState.player == null or not GameState.player.alive:
		_pending_kickoff = []
		_pending_season = []
		return
	if _season_card_blocked():
		return  # WU-495: queued behind dialogue, friend, road and contest cards; their close re-runs this
	var season := ""
	var year := 1
	var back := PackedStringArray()
	var coming := PackedStringArray()
	if not _pending_season.is_empty():
		season = _pending_season[0]
		year = int(_pending_season[1])
		back = _pending_season[2]
	if not _pending_kickoff.is_empty():
		season = _pending_kickoff[0]
		year = int(_pending_kickoff[1])
		coming = _pending_kickoff[2]
	_pending_kickoff = []
	_pending_season = []
	_choice_menu.close()
	_close_screens()
	_season_card.open(season, year, back, coming)
	Audio.play("chime_info")
	_update_modal()


## WU-495: true while another card or dialogue is up; the season card waits for it.
## WU-602: the joining card, once per join; WU-604: queued so it waits for the hall menu to close.
func _on_sect_joined(sect_id: String) -> void:
	if not GameState.data.sects.has(sect_id):
		return
	_pending_moments.append({"kind": "sect_join", "sect_id": sect_id})
	_update_modal()


func _sect_color(sect_id: String) -> Color:
	var def: SectDef = GameState.data.sects[sect_id]
	return Color(String(def.robe_color)) if String(def.robe_color) != "" else UIStyle.ACCENT


func _play_sect_join(sect_id: String) -> void:
	if GameState.player.is_rogue():
		return
	_sect_card.open(Guidance.sect_welcome(GameState.player, GameState.data, sect_id, GameState.current_region), _sect_color(sect_id), sect_id)
	_update_modal()


## WU-604: the welcome card after reporting at the hall.
func _on_sect_reported(sect_id: String, items: Dictionary) -> void:
	if not GameState.data.sects.has(sect_id):
		return
	_pending_moments.append({"kind": "sect_report", "sect_id": sect_id, "line": GameState.last_report_line, "items": items.duplicate()})
	_update_modal()


func _play_sect_report(sect_id: String, line: String, items: Dictionary) -> void:
	var p := GameState.player
	if p.is_rogue():
		return
	var rows: Array = []
	for item_id: String in items:
		var nm: String = GameState.data.items[item_id].name if GameState.data.items.has(item_id) else item_id
		rows.append([item_id, "%d x %s" % [int(items[item_id]), nm]])
	var def: SectDef = GameState.data.sects[sect_id]
	_sect_card.open_report(def.name, def.rank_name(int(p.sect["rank"])), line, rows,
		Guidance.hall_services(p, GameState.data, GameState.current_region, GameClock.total_days, GameState.world_flags), GameState.data, _sect_color(sect_id), sect_id)
	_update_modal()


## WU-609: the hall or mission board asked for the trial; stage the card over a cleared screen.
func _on_promotion_trial_offered(sect_id: String) -> void:
	if not GameState.data.sects.has(sect_id) or GameState.player.is_rogue():
		return
	_trial_return = ""
	if _mission_board_n != null and _mission_board_n.visible:
		_trial_return = "board"
	elif _choice_menu.visible and is_instance_valid(_last_source):
		_trial_return = "hall"
	_choice_menu.close()
	_close_screens()
	_trial_stepped = false
	_trial_card.open(GameState.player, GameState.data, _sect_color(sect_id))
	_update_modal()


## WU-614: a lost trial is told on the card, through the moments queue (ahead of the return to the board/hall).
func _on_promotion_trial_lost(sect_id: String, info: Dictionary) -> void:
	if not GameState.data.sects.has(sect_id) or GameState.player.is_rogue():
		return
	_pending_moments.append({"kind": "trial_lost", "sect_id": sect_id, "info": info})
	_update_modal()


## WU-611: the hall asked for the contest card; stage it over a cleared screen.
func _on_sect_contest_offered(sect_id: String) -> void:
	if not GameState.data.sects.has(sect_id) or GameState.player.is_rogue():
		return
	_contest_return = _choice_menu.visible and is_instance_valid(_last_source)
	_choice_menu.close()
	_close_screens()
	_sect_contest_card.open(GameState.player, GameState.data, GameClock.total_days, _sect_color(sect_id), Rivals.rival_of(GameState.player, GameState.npcs))
	_update_modal()


## WU-611: each bout is told on the card, through the moments queue.
func _on_sect_contest_bout(sect_id: String, info: Dictionary) -> void:
	if not GameState.data.sects.has(sect_id) or GameState.player.is_rogue():
		return
	_pending_moments.append({"kind": "contest_bout", "sect_id": sect_id, "info": info})
	if bool(info.get("won", false)) and String(info.get("next_foe", "")) == "":  # GFX-256: the last round won
		_pending_moments.append({"kind": "contest_champion", "sect_id": sect_id})
	_update_modal()


func _on_sect_contest_confirmed() -> void:
	GameState.enter_sect_contest()
	if _contest_return:  # back to the hall menu after the last result
		_pending_moments.append({"kind": "trial_return", "to": "hall"})
		_contest_return = false
	_update_modal()


func _on_sect_contest_card_closed() -> void:
	if _pending_moments.is_empty() and _contest_return:
		_return_from_trial("hall")
		_contest_return = false
	_update_modal()
	_drain_moments.call_deferred()


func _on_trial_confirmed() -> void:
	_trial_stepped = true
	_update_modal()
	GameState.attempt_promotion_trial()
	if _trial_return != "":  # WU-612: after the fight and the promotion moment, back to where it was offered
		_pending_moments.append({"kind": "trial_return", "to": _trial_return})
		_trial_return = ""
		_update_modal()


## WU-612: "Not yet" / B return to the board or hall; "Step into the arena" is handled in _on_trial_confirmed.
func _on_trial_card_closed() -> void:
	if not _trial_stepped:
		_return_from_trial(_trial_return)
		_trial_return = ""
	_trial_stepped = false
	_update_modal()


func _return_from_trial(to: String) -> void:
	if GameState.player == null or GameState.player.is_rogue():
		return
	if to == "board":
		_mission_board.open("rank")
	elif to == "hall" and is_instance_valid(_last_source):
		_choice_menu.open_for(_last_source)


## WU-603: the promotion card reuses the sect card.
func _on_sect_promoted(sect_id: String, _rank: int) -> void:
	if not GameState.data.sects.has(sect_id) or GameState.player.is_rogue():
		return
	# Review: queued like the join card, so it never opens over the still-open mission board (which keeps focus).
	# The summary is captured now so two queued promotions each show their own rank.
	_pending_moments.append({"kind": "sect_promoted", "sect_id": sect_id,
		"summary": Sects.promotion_summary(GameState.player, GameState.data),
		"has_next": Sects.next_rank(GameState.player, GameState.data) >= 0})
	_update_modal()


func _play_sect_promoted(sect_id: String, summary: Dictionary, has_next: bool) -> void:
	if GameState.player.is_rogue():
		return
	var def: SectDef = GameState.data.sects[sect_id]
	_sect_card.open_promotion(def.name, summary, has_next, _sect_color(sect_id), sect_id)
	_update_modal()


## WU-617: a technique level-up plays as a small card through the moments queue.
func _on_technique_leveled(tech_id: String, level: int, before: String, after: String) -> void:
	_pending_moments.append({"kind": "technique_level", "tech_id": tech_id, "level": level, "before": before, "after": after})
	_update_modal()


func _play_technique_level(m: Dictionary) -> void:
	var def: TechniqueDef = GameState.data.techniques.get(String(m["tech_id"]))
	if def == null:
		return
	_sect_card.open_technique(def.name, int(m["level"]), String(m["before"]), String(m["after"]), int(m["level"]) >= def.max_level)
	_update_modal()


## WU-606: the monthly lecture plays as a card through the moments queue.
func _on_sect_lecture_attended(sect_id: String, result: Dictionary) -> void:
	if not GameState.data.sects.has(sect_id) or GameState.player.is_rogue():
		return
	_pending_moments.append({"kind": "sect_lecture", "sect_id": sect_id, "result": result})
	_update_modal()


func _play_sect_lecture(sect_id: String, result: Dictionary) -> void:
	if GameState.player.is_rogue() or not GameState.data.sects.has(sect_id):
		return
	var def: SectDef = GameState.data.sects[sect_id]
	var name := String(result.get("name", "the lecture"))
	var line := String(result.get("line", ""))
	if line == "":
		line = "You attend %s." % name
	_sect_card.open_lecture(def.name, name, line, int(result.get("qi", 0)), String(result.get("insight_name", "")), _sect_color(sect_id), bool(result.get("qi_capped", false)))
	_update_modal()


func _season_card_blocked() -> bool:
	if _dialogue.visible and not _dialogue.closed.is_connected(_flush_year_review):
		_dialogue.closed.connect(_flush_year_review, CONNECT_ONE_SHOT)
	if is_instance_valid(RoadCard.current) and not RoadCard.current.finished.is_connected(_flush_year_review):
		RoadCard.current.finished.connect(_flush_year_review, CONNECT_ONE_SHOT)
	return _dialogue.visible or is_instance_valid(RoadCard.current) or _friend_card.visible or _contest_card.visible or _season_card.visible or _sect_card.visible or _trial_card.visible or _sect_contest_card.visible or _encounter.visible or _combat_report.visible \
			or _realm_card.visible or _tribulation.visible or _any_screen_open()


## The year review stays a banner (WU-031); the season recap now rides on the season card.
func _flush_recap_banner() -> void:
	if _pending_year.is_empty() or _time_skip.visible or _respawn.visible or _death_screen.visible or not GameState.pending_respawn.is_empty():
		return
	if GameState.player == null or not GameState.player.alive:
		return
	_pending_season = []
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


## WU-438: a new game opens with the starting region's name card (a load shows its recap instead).
func _show_start_arrival() -> void:
	var pending: bool = GameState.arrival_banner_pending
	GameState.arrival_banner_pending = false
	if pending and GameState.player != null and GameState.player.alive and GameState.pending_respawn.is_empty():
		var region_id: String = GameState.current_region
		var road_choice := has_road_choice(GameState.pending_encounter, GameState.last_travel_road_encounter)
		if is_instance_valid(RoadCard.current):
			RoadCard.current.finished.connect(func(): _after_road_card(region_id, road_choice), CONNECT_ONE_SHOT)  # WU-447, WU-452
		else:
			_after_road_card(region_id, road_choice)


## WU-452: true when the journey just made left a road encounter with a choice waiting to be answered.
static func has_road_choice(pending_encounter: String, road_encounter: String) -> bool:
	return pending_encounter != "" and road_encounter != ""


## WU-452: order is road card -> road encounter -> arrival banner. The window opens now (the card is over) and the
## arrival banner waits for it to close; without a choice the banner shows at once.
func _after_road_card(region_id: String, road_choice: bool) -> void:
	if road_choice and GameState.pending_encounter != "" and GameState.player != null and GameState.player.alive:
		_arrival_waiting = region_id
		_on_encounter_choice_requested(GameState.pending_encounter)
	else:
		_show_arrival(region_id)


## WU-438: the GUIDE-209 arrival line for `region_id`, "" when it is not today's or is empty.
static func arrival_extra(flags: Dictionary, region_id: String) -> String:
	if String(flags.get("arrival_region", "")) != region_id:
		return ""
	return String(flags.get("arrival_line", ""))


## Arrival card: region name with qi density and danger, shown on real travel.
func _on_arrival(region_id: String) -> void:
	if is_instance_valid(RoadCard.current):
		return # the road card is up: the reloaded HUD shows the arrival when it ends (WU-447)
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


## Arrival banner subtitle (WU-192, WU-514): "First visit · Qi x1.5 · Calm · Known here: Respected".
## `c` may be null (no title).
static func arrival_subtitle(c: CharacterData, data: GameData, region_id: String, qi: float, danger: String, first_visit: bool) -> String:
	var sub := "Qi x%s · %s" % [Exploration.format_density(qi), danger]
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
	var qi := Exploration.effective_density(data, region_id, GameState.world_flags, GameClock.total_days, GameState.world_events, GameState.player)
	var first_visit := GameState.last_arrival_first_visit
	var sub := arrival_subtitle(GameState.player, data, region_id, qi, WorldMapScreen.danger_name(data, region_id), first_visit)
	if first_visit:  # WU-544: who teaches here
		var teach := Npcs.region_teaching_lines(Npcs.region_teachings(GameState.player, data, GameState.npc_favor, region_id))
		if not teach.is_empty():
			sub += "\n" + "\n".join(teach)
	# WU-514: today's line is in the message log and Next steps, not repeated on the banner.
	var hold := Banner.SLIM_HOLD_SECONDS  # WU-510: a slim banner that leaves the village visible
	_arrival_title = Exploration.region_name(data, region_id)
	if _blocking_except_encounter():
		return # WU-491: a screen is open; the name card is not shown over it
	_banner.announce(_arrival_title, sub, UIStyle.ACCENT, hold, false, null, true, UIStyle.arrival_danger_color(WorldMapScreen.danger_name(data, region_id)))


func _on_breakthrough(success: bool, realm_name: String) -> void:
	if _breakthrough.is_attempting() and _breakthrough.visible:
		# GFX-258: the stage plays its beat first; the card or banner follows when the window closes.
		if _breakthrough_frame < 0:
			_breakthrough_frame = Engine.get_process_frames()
		_breakthrough.closed.connect(_on_breakthrough.bind(success, realm_name), CONNECT_ONE_SHOT)
		return
	var details := _breakthrough_details
	_breakthrough_details = ""
	var surpassed := GameState.last_surpassed_rival
	GameState.last_surpassed_rival = ""
	if success:
		_show_realm_card.call_deferred(realm_name, details, surpassed)
		return
	_breakthrough_frame = -1
	if details != "" and GameState.player != null and GameState.data != null:
		# GFX-260: a failed gate opens a card (stage, qi lost, injury, lessons) through the realm-card path.
		_pending_realm_card = [realm_name, "", details, [], "", true]
		if not _tribulation.visible:
			_open_pending_realm_card()
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
	var since := _breakthrough_frame if _breakthrough_frame >= 0 else Engine.get_process_frames()
	_breakthrough_frame = -1
	if int(Settings.get_value("hud_hints")) > 0:
		for entry in _recent_notices:
			if int(entry[0]) >= since - 1:
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
	var look := PlayerLook.of(GameState.player, GameState.data)
	if card.size() > 5:
		_realm_card.open_failed(card[0], RealmCard.failed_lines(card[2]), look, GameState.player.realm_index + 1)
	else:
		_realm_card.open(card[0], card[1], card[2], card[3], card[4], look, GameState.player.realm_index)
	_update_modal()


## WU-454: the podium card after a festival contest; waits for a running road card.
func _on_contest_finished(result: Dictionary) -> void:
	if is_instance_valid(RoadCard.current):
		RoadCard.current.finished.connect(func(): _show_contest_card(result), CONNECT_ONE_SHOT)
	else:
		_show_contest_card.call_deferred(result)


## WU-635: the seated-together card, then the meditation itself.
func _on_friend_meditation_requested(npc_id: String, npc_name: String, density: float) -> void:
	_choice_menu.close()
	_friend_med_card.open(npc_id, npc_name)
	_friend_med_card.done.connect(GameState.meditate_with_friend.bind(npc_id, density), CONNECT_ONE_SHOT)
	_update_modal()


## WU-467: the friend scene card; waits for the conversation (and a road card) that triggered it to finish.
func _on_friend_scene(npc_id: String, npc_name: String, text: String, gift_name: String, gift_id: String = "") -> void:
	_queue_friend_card([npc_id, npc_name, text, gift_name, gift_id, ""])


## WU-629: the congratulate reply, face to face.
func _on_friend_congratulated(npc_id: String, npc_name: String, text: String) -> void:
	_queue_friend_card([npc_id, npc_name, text, "", "", "", true])


## WU-479: a friend's lesson shows on the same card, queued exactly like a scene.
func _on_lesson_taught(npc_id: String, npc_name: String, text: String, effect_line: String) -> void:
	_queue_friend_card([npc_id, npc_name, text, "", "", effect_line])


func _queue_friend_card(entry: Array) -> void:
	_pending_friend_scenes.append(entry)
	if _contest_card.visible:
		pass  # FOLK-016: shown when the contest card closes (_flush_friend_scenes is connected to its `closed`)
	elif _dialogue.visible:
		if not _dialogue.closed.is_connected(_flush_friend_scenes):
			_dialogue.closed.connect(_flush_friend_scenes, CONNECT_ONE_SHOT)
	elif is_instance_valid(RoadCard.current):
		if not RoadCard.current.finished.is_connected(_flush_friend_scenes):
			RoadCard.current.finished.connect(_flush_friend_scenes, CONNECT_ONE_SHOT)
	else:
		_flush_friend_scenes.call_deferred()


func _flush_friend_scenes() -> void:
	if _pending_friend_scenes.is_empty() or _friend_card.visible or _season_card.visible or _contest_card.visible:
		return
	if _dialogue.visible:  # review: queued just before start_dialogue opened it; show once it closes
		if not _dialogue.closed.is_connected(_flush_friend_scenes):
			_dialogue.closed.connect(_flush_friend_scenes, CONNECT_ONE_SHOT)
		return
	if GameState.player == null or not GameState.player.alive:
		_pending_friend_scenes.clear()
		return
	var scene: Array = _pending_friend_scenes.pop_front()
	_friend_card.open(String(scene[0]), String(scene[1]), String(scene[2]), String(scene[3]), String(scene[4]) if scene.size() > 4 else "", String(scene[5]) if scene.size() > 5 else "", scene.size() > 6 and bool(scene[6]))
	_update_modal()


func _show_contest_card(result: Dictionary) -> void:
	if GameState.player == null or not GameState.player.alive:
		return
	_choice_menu.close()
	_close_screens()
	_contest_card.open(result, GameState.data)
	_update_modal()


## Settings replaces the pause menu while open, then returns to it.
func _open_settings() -> void:
	_pause_menu.visible = false
	_settings_screen().open()


## Help replaces the pause menu while open, then returns to it.
func _open_help() -> void:
	_help_from_key = false
	_pause_menu.visible = false
	_help_screen().open()


## The journal opens from the pause menu (no free gamepad button), closing it first.
func _open_journal() -> void:
	_pause_menu.close()
	var journal: Control = _screen("toggle_journal")
	journal.open()
	_update_modal()


## WU-419: the calendar replaces the journal while open.
func _open_calendar_from_journal() -> void:
	_close_screens()
	_screen("open_calendar").open()
	_update_modal()


## The village book replaces the journal or character sheet it was opened from (`from`) while open;
## closing it returns to that screen so focus lands back on the button.
func _open_village_book(from: String = "toggle_journal") -> void:
	_book_from = from
	_screen(from).close()
	_village_book.open()
	_update_modal()


func _on_book_closed() -> void:
	var from := _book_from
	_book_from = ""
	if from == "toggle_character_sheet" and GameState.has_session() and GameState.player.alive:
		_screen(from).open()
	_update_modal()


## Load replaces the pause menu while open, then returns to it.
func _open_load() -> void:
	_pause_menu.visible = false
	_load_screen_node().open()


func _on_load_closed() -> void:
	if GameState.has_session() and GameState.player.alive:
		_pause_menu.open()
	_update_modal()


func _on_slot_chosen(slot: String) -> void:
	if SaveManager.load_game(slot):
		get_tree().reload_current_scene()
	else:
		_load_screen_node().open()


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


## WU-165: 0.35 when any covered screen rect (WU-511: the player's body only) touches the panel, else 1.0.
static func panel_alpha(panel_rect: Rect2, covered: Array[Rect2]) -> float:
	for r in covered:
		if panel_rect.intersects(r):
			return 0.35
	return 1.0


func _process(delta: float) -> void:
	_poll_digest()
	_fade_timer -= delta
	if _fade_timer <= 0.0:
		_fade_timer = 0.1
		_fade_targets = _compute_fade_targets()
		if _target_name != "" and _prompt != null and _prompt.visible:
			_place_prompt()  # WU-478: the player and camera move; keep the chip beside its figure
	if _status_panel == null or _log_panel == null:
		return
	var k := 1.0 if MotionFx.reduced() else minf(1.0, 8.0 * delta)
	var log_target := _fade_targets.y
	if _log_lines.is_empty():  # WU-489: no empty framed box on a new game; fades in with the first message
		log_target = 0.0
	var idle := log_idle_alpha(float(Time.get_ticks_msec() - _last_message_msec) / 1000.0)
	if idle < 1.0 and not _log_panel.get_global_rect().has_point(_log_panel.get_global_mouse_position()):
		log_target = minf(log_target, idle)
	_status_panel.modulate.a = lerpf(_status_panel.modulate.a, _fade_targets.x, k)
	_log_panel.modulate.a = lerpf(_log_panel.modulate.a, log_target, k)
	_guide_panel.modulate.a = lerpf(_guide_panel.modulate.a, _fade_targets.z, k)
	if _key_bar != null:
		_key_bar.modulate.a = lerpf(_key_bar.modulate.a, _key_bar_fade, k)


## GFX-010: the log's target alpha after `seconds_since` seconds without a new message.
static func log_idle_alpha(seconds_since: float) -> float:
	return LOG_IDLE_ALPHA if seconds_since >= LOG_IDLE_SECONDS else 1.0


## WU-472: names of the panels (keys of panel_rects) whose rect touches the player's rect.
static func fade_targets(panel_rects: Dictionary, player_rect: Rect2) -> Array[String]:
	var out: Array[String] = []
	for key: String in panel_rects:
		if (panel_rects[key] as Rect2).intersects(player_rect):
			out.append(key)
	return out


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
	_key_bar_fade = 1.0
	if _key_bar != null and _key_bar.visible:
		var behind := fade_targets({"key_bar": _key_bar.get_global_rect()}, Rect2(pp - Vector2(20, 25), Vector2(40, 50)))
		if not behind.is_empty():
			_key_bar_fade = 0.3
	covered.append(Rect2(pp - Vector2(20, 25), Vector2(40, 50)))
	# WU-511: only the player's own body fades a panel; a nearby name label or beast behind it does not.
	return Vector3(
		minf(panel_alpha(_status_panel.get_global_rect(), covered), card_fade_target(_status_panel.get_global_rect(), pp)),
		minf(panel_alpha(_log_panel.get_global_rect(), covered), card_fade_target(_log_panel.get_global_rect(), pp)),
		minf(panel_alpha(_guide_panel.get_global_rect(), covered), card_fade_target(_guide_panel.get_global_rect(), pp)))


## WU-416: picks up a fresh GameState.last_digest and shows its card once nothing else is up.
func _poll_digest() -> void:
	var d: Dictionary = GameState.last_digest
	if d.is_empty():
		_digest_seen = {}
		_digest_pending = {}
		if _digest_card.visible:
			_digest_card.dismiss()
		return
	if not is_same(d, _digest_seen):
		_digest_seen = d
		_digest_pending = d if DigestCard.should_show(d) else {}
	if _digest_pending.is_empty():
		return
	if digest_blocked():
		return
	_digest_card.show_digest(_digest_pending)
	_digest_pending = {}


## True while a banner, modal, report or the death screen is up (the digest queues behind them).
func digest_blocked() -> bool:
	if _banner.visible or _banner.queued_count() > 0 or _time_skip.visible or _status_panel == null or not _status_panel.visible:
		return true
	return GameState.player == null or not GameState.player.alive or not GameState.pending_respawn.is_empty() or _death_screen.visible


## WU-491: true while any HUD modal is open (the name card never draws over one).
func _is_blocking() -> bool:
	return _blocking_except_encounter() or _encounter.visible


func _blocking_except_encounter() -> bool:
	return _choice_menu.visible or _dialogue.visible or _quarrel.visible or _cast_bar.visible or _any_screen_open() or _combat_report.visible or _tribulation.visible or _respawn.visible or _realm_card.visible or _contest_card.visible or _friend_card.visible or _season_card.visible or _sect_card.visible or _trial_card.visible or _sect_contest_card.visible or _season_board.visible or _pause_menu.visible or _up(_settings) or _up(_help) or _up(_load_screen) or _death_screen.visible


func _update_modal() -> void:
	var blocking := _is_blocking()
	if blocking and _arrival_title != "":
		_banner.dismiss_titled(_arrival_title)  # WU-491: the name card never stays over an open screen
		_arrival_title = ""
	# The status panel, hints and log hide behind modals; a time-skip overlay alone keeps them.
	_status_panel.visible = not blocking
	if blocking and _digest_card != null:
		_digest_card.dismiss()
	_log_panel.visible = not blocking
	_backdrop.visible = blocking
	_prompt.visible = not blocking and not _time_skip.visible and not _sworn_oath.visible  # GFX-228: no "[E] name" over a card
	_place_prompt()
	_update_guide_visibility()
	_key_bar.visible = bool(Settings.get_value("key_help")) and not blocking
	EventBus.ui_modal_changed.emit(blocking or _time_skip.visible)
	_hold_banners()
	if not _pending_moments.is_empty() and not blocking and not _time_skip.visible and not _sworn_oath.visible:
		_drain_moments.call_deferred()  # WU-601
	if not blocking and (not _pending_kickoff.is_empty() or not _pending_season.is_empty()):
		_flush_year_review.call_deferred()  # WU-534: a season card queued behind an open screen


## WU-523: banners wait while any modal (screen, shop, dialogue, report, menu) is up, then play in order.
func _hold_banners() -> void:
	_banner.set_held(_is_blocking())


func _return_to_menu() -> void:
	_showing_skip = {}
	_pending_moments.clear()  # WU-601
	GameState.end_session()
	get_tree().change_scene_to_file(MAIN_MENU)


## "Rain" or "Rain (tomorrow: Clear)" (GUIDE-202).
func _weather_label(data: GameData) -> String:
	var today := Weather.label(Weather.of(data, GameState.current_region, GameClock.total_days))
	var next: Array[String] = Weather.forecast(data, GameState.current_region, GameClock.total_days, 1)
	return "%s (tomorrow: %s)" % [today, Weather.label(next[0])]


## GFX-016: "Neutral · Azure Cloud Sect, Outer Disciple" (the alignment number stays on the sheet).
static func alignment_line(tier: String, affiliation: String) -> String:
	return "%s · %s" % [tier, affiliation]


## "~70 days to the next stage" for the status card ("" like next_layer_text).
static func next_stage_short(days: int, c: CharacterData, data: GameData) -> String:
	var text := next_layer_text(days, c, data)
	return text.trim_suffix(" here")


## "Qi x1.8" chip text for a region's qi density (WU-507).
static func region_chip_text(density: float) -> String:
	return "Qi x%s" % Exploration.format_density(density)


## Green above x1.5, plain below x1 (WU-507).
static func region_chip_color(density: float) -> Color:
	if density > 1.5:
		return Color(0.5, 0.9, 0.55)
	if density < 1.0:
		return Color(0.9, 0.65, 0.4)
	return Color(0.82, 0.84, 0.9)


## `region` and the estimate on one line, or two when that line is wider than `max_width`.
static func region_line(region: String, estimate: String, font: Font = null, font_size: int = 13, max_width: float = 0.0) -> String:
	if estimate == "":
		return region
	var one := "%s · %s" % [region, estimate]
	if font != null and max_width > 0.0 and font.get_string_size(one, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		return "%s\n%s" % [region, estimate]
	return one


## `text` wrapped at word boundaries to `width` px, one entry per rendered line.
static func wrapped_lines(text: String, font: Font, font_size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in text.split("\n"):
		var para := TextParagraph.new()
		para.width = width
		para.break_flags = TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY
		para.add_string(raw, font, font_size)
		for i in para.get_line_count():
			var r := para.get_line_range(i)
			out.append(raw.substr(r.x, r.y - r.x).strip_edges())
	return out


## At most `max_lines` lines; past that the last one becomes "... more in the journal (J)".
static func overflow_cut(lines: PackedStringArray, max_lines: int) -> PackedStringArray:
	if lines.size() <= max_lines:
		return lines
	var out := lines.slice(0, maxi(max_lines - 1, 0))
	out.append("... more in the journal (J)")
	return out


## WU-429/WU-579: entry-aware cut. Whole entries are kept while they fit; the first entry that does not fit keeps
## its leading wrapped lines when at least 3 words survive (ending "..." at a word boundary, never on a bare
## preposition), else it is dropped, and so is everything after it. "More in the Journal (J)" closes a cut list
## only when it fits `max_lines`. Returns `entries` unchanged when everything fits.
static func cut_entries(entries: PackedStringArray, font: Font, font_size: int, width: float, max_lines: int) -> PackedStringArray:
	var counts: Array[int] = []
	var total := 0
	for e in entries:
		var n := maxi(1, wrapped_lines(e, font, font_size, width).size())
		counts.append(n)
		total += n
	if total <= max_lines:
		return entries
	var out := PackedStringArray()
	var room := maxi(1, max_lines - 1)
	var used := 0
	for i in entries.size():
		if used + counts[i] <= room:
			out.append(entries[i])
			used += counts[i]
			continue
		var left := room - used
		if left >= 1:
			var part := trim_entry(entries[i], font, font_size, width, left)
			if part != "":
				out.append(part)
				used += maxi(1, wrapped_lines(part, font, font_size, width).size())
		break
	if used + 1 <= max_lines:
		out.append("More in the Journal (J)")
	elif out.is_empty():
		out.append(trim_entry(entries[0], font, font_size, width, 1))
	return out


## WU-626: the whole (compacted) goal when it fits the row's two lines; else the word-cut short form.
static func goal_row(goal: String, data: GameData, font: Font) -> String:
	var compact := Guidance.compact_goal(goal, data)
	if wrapped_lines(compact, font, 14, GOAL_W).size() <= 2:
		return compact
	return fit_goal(Guidance.short_goal(goal, data), font)


## WU-580: the goal row at the card's width, at most 2 lines, trimmed at a word with an ellipsis (tooltip keeps the full text).
static func fit_goal(text: String, font: Font) -> String:
	if wrapped_lines(text, font, 14, GOAL_W).size() <= 2:
		return text
	var t := trim_entry(text, font, 14, GOAL_W, 2)
	return t if t != "" else ellipsize_first_line(text, font, 14, GOAL_W)


const _DANGLERS: PackedStringArray = ["a", "an", "the", "to", "of", "off", "on", "in", "at", "for", "from", "and", "or", "with", "by", "into", "up", "out", "your", "his", "her", "their", "is", "are", "be", "where", "when", "how", "what", "who", "that", "which", "if", "as", "until", "so", "but", "opens", "near"]


## The first `lines` wrapped lines of `text`, cut back to a word boundary and ended with "...". "" when fewer than
## 3 words would remain (the leading "> " does not count as a word).
static func trim_entry(text: String, font: Font, font_size: int, width: float, lines: int) -> String:
	var ell := "…" if font.has_char(0x2026) else "..."
	var wrapped := wrapped_lines(text, font, font_size, width)
	var kept := " ".join(wrapped.slice(0, lines))
	var words := Array(kept.split(" ", false))
	while not words.is_empty():
		var cand := " ".join(words).rstrip(",;:.-") + ell
		var real := words.filter(func(w: String) -> bool: return w != ">" and w != "-")
		if real.size() < 3:
			return ""
		var last := String(words[-1]).to_lower().rstrip(",;:.-")
		if last not in _DANGLERS and wrapped_lines(cand, font, font_size, width).size() <= lines:
			return cand
		words.remove_at(words.size() - 1)
	return ""


## First wrapped line of `text`, ended with "…" at a word boundary and still one line wide.
static func ellipsize_first_line(text: String, font: Font, font_size: int, width: float) -> String:
	var lines := wrapped_lines(text, font, font_size, width)
	var line := lines[0] if not lines.is_empty() else text
	var words := line.split(" ", false)
	while words.size() > 1:
		var cand := " ".join(words).rstrip(",;:.-") + "…"
		if wrapped_lines(cand, font, font_size, width).size() <= 1:
			return cand
		words.remove_at(words.size() - 1)
	return (words[0] if not words.is_empty() else line).rstrip(",;:.-") + "…"


## The key strip's translucent dark backing (GFX-016).
static func key_bar_style() -> StyleBoxFlat:
	var style := UIStyle.flat_panel_style()
	style.bg_color.a = 0.6
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.set_content_margin_all(4)
	return style


## Alpha a card takes while the player (screen position) is within CARD_FADE_MARGIN of its rect.
static func card_fade_target(card_rect: Rect2, player_screen_pos: Vector2) -> float:
	return CARD_FADE_ALPHA if card_rect.grow(CARD_FADE_MARGIN).has_point(player_screen_pos) else 1.0


func _on_region_changed_fair_fight(_id: String) -> void:
	_queue_fair_fight()


func _on_days_advanced_fair_fight(_d: int) -> void:
	_queue_fair_fight()


func _on_region_changed_refresh(_id: String) -> void:
	_refresh()


func _on_player_respawned(_anchor_id: String, _lives: int) -> void:
	_refresh()
	_open_pending_respawn()


func _on_breakthrough_details(text: String) -> void:
	_breakthrough_details = text


func _on_dialogue_ended(_id: String) -> void:
	_dialogue.close()


func _on_session_started_season() -> void:
	_season = Calendar.season_of(GameClock.total_days)


## GFX-099: draws the key bar's "[X]" keys as small key caps (lighter box, 1 px shadow) behind its text.
class KeyCaps extends Control:
	var bar: Label

	func _draw() -> void:
		if bar == null or bar.text == "":
			return
		var font := bar.get_theme_font("font")
		var fs := bar.get_theme_font_size("font_size")
		var sb := bar.get_theme_stylebox("normal")
		var mr := sb.get_margin(SIDE_RIGHT) if sb != null else 0.0
		for r in UIStyle.key_cap_rects(font, fs, bar.text, size.x, mr, size.y):
			draw_rect(Rect2(r.position + Vector2(0, 1), r.size), Color(0, 0, 0, 0.6))
			draw_rect(r, Color(0.28, 0.29, 0.34, 0.9))
