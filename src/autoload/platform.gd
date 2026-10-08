extends Node
## Platform layer for Steam (REL-009). Every call is a safe no-op unless the
## GodotSteam singleton "Steam" exists, so no binary is needed yet. The first
## skipped call is logged once (verbose); `backend` can be set by tests.

## Object that receives Steam calls; null means "not on Steam". Auto-detected in _ready().
var backend: Object = null
## Last text passed to set_rich_presence (kept even without Steam, for UI/tests).
var presence: String = ""
var _logged_missing: bool = false


func _ready() -> void:
	if Engine.has_singleton("Steam"):
		backend = Engine.get_singleton("Steam")


func is_steam() -> bool:
	return backend != null


## Unlocks a Steam achievement; the id matches the milestone id.
func unlock_achievement(id: String) -> void:
	if backend == null:
		_note_missing()
		return
	backend.call("setAchievement", id)
	backend.call("storeStats")


func set_rich_presence(text: String) -> void:
	presence = text
	if backend == null:
		_note_missing()
		return
	backend.call("setRichPresence", "steam_display", "#Status")
	backend.call("setRichPresence", "status", text)


## "<realm label> in <region name>" for the current session, or "" without one.
func presence_text() -> String:
	if not GameState.has_session():
		return ""
	return "%s in %s" % [Cultivation.realm_label(GameState.player, GameState.data), Exploration.region_name(GameState.data, GameState.current_region)]


## Pushes the current presence text if it changed.
func refresh_presence() -> void:
	var text := presence_text()
	if text != "" and text != presence:
		set_rich_presence(text)


func _note_missing() -> void:
	if not _logged_missing:
		_logged_missing = true
		if OS.is_stdout_verbose():
			print("Platform: Steam not available; achievements and presence are skipped.")
