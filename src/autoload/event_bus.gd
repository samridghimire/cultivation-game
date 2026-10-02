extends Node
## Global signal hub. Gameplay systems emit here and UI listens, so neither
## needs a direct reference to the other.

## A line for the in-game message log. category: info, progress, warning, danger, karma.
signal message_posted(text: String, category: String)
## Any player state changed; UI should refresh.
signal player_changed
signal session_started
signal breakthrough_attempted(success: bool, realm_name: String)
signal player_died(cause: String)
## The interactable the player would use by pressing interact ("" = none).
signal interaction_target_changed(display_name: String)
## Player asked to interact with `source` (an Interactable).
signal interaction_menu_requested(source: Node)
## A modal UI (menu, character sheet) opened or closed; world input should pause.
signal ui_modal_changed(is_open: bool)
## The player travelled to another region; the world scene rebuilds itself.
signal region_changed(region_id: String)
## A fight ended (GameState.fight). `log` is the full blow-by-blow.
signal combat_finished(enemy_name: String, victory: bool, log: PackedStringArray)

## A conversation with an NPC started; render GameState.dialogue_view().
signal dialogue_requested(npc_id: String)
## The conversation ended (after its effects and time were applied).
signal dialogue_ended(npc_id: String)

func post(text: String, category: String = "info") -> void:
	message_posted.emit(text, category)
