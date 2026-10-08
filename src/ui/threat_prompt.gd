class_name ThreatPrompt
extends Node
## ChoiceMenu source for a sensed lethal foe (FH-004b): slip away or fight.
## Closing the menu any way counts as slipping away, so no threat stays pending.

var display_name := ""
var _enemy_id := ""


func prepare(enemy_id: String) -> void:
	_enemy_id = enemy_id
	var enemy: Dictionary = GameState.data.enemies[enemy_id]
	display_name = "A %s is near" % enemy["name"]


func menu_options() -> Array[Dictionary]:
	var enemy: Dictionary = GameState.data.enemies[_enemy_id]
	var pct := roundi(Combat.win_chance(GameState.player, GameState.data, enemy) * 100.0)
	var options: Array[Dictionary] = []
	options.append({"label": "Slip away (1 day)", "action": GameState.face_threat.bind(false)})
	options.append({
		"label": "Fight it (%s, %d%% to win)" % [UIStyle.fight_label(GameState.player, GameState.data, enemy), pct],
		"action": GameState.face_threat.bind(true),
	})
	return options


func on_menu_closed() -> void:
	if GameState.pending_threat != "":
		GameState.face_threat(false)
