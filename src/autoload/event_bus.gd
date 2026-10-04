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
## The Creation Artifact saved the player from a violent death (respawned at anchor_id, "" = start region).
signal player_respawned(anchor_id: String, lives_left: int)
## The interactable the player would use by pressing interact ("" = none).
signal interaction_target_changed(display_name: String)
## Player asked to interact with `source` (an Interactable).
signal interaction_menu_requested(source: Node)
## The player chose to craft at a workshop; open the crafting screen for this profession id.
signal crafting_requested(prof_id: String)
## The player opened their sect's mission board (sect hall); show the MissionBoard.
signal mission_board_requested
## The player wants to direct their children's training; show the ChildTrainingScreen.
signal child_training_requested
## A modal UI (menu, character sheet) opened or closed; world input should pause.
signal ui_modal_changed(is_open: bool)
## The player travelled to another region; the world scene rebuilds itself.
signal region_changed(region_id: String)
## A fight ended (GameState.fight). `log` is the full blow-by-blow.
signal combat_finished(enemy_name: String, victory: bool, log: PackedStringArray)

## An explored encounter offers choices: render GameState.encounter_choices()
## and call GameState.choose_encounter(index).
signal encounter_choice_requested(encounter_id: String)
## The pending encounter choice was made (its outcome was applied).
signal encounter_choice_resolved

## A conversation with an NPC started; render GameState.dialogue_view().
signal dialogue_requested(npc_id: String)
## The conversation ended (after its effects and time were applied).
signal dialogue_ended(npc_id: String)

func post(text: String, category: String = "info") -> void:
	message_posted.emit(text, category)
