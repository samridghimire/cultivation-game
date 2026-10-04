extends Interactable
## An orphanage or temple that cares for foundlings: adopt one for a donation
## (GameState.adopt_foundling). Disabled entries show Adoption.check_foundling's
## reason. Orphans living in the region are adopted from their own NPC menu.


func get_options() -> Array[Dictionary]:
	var c: CharacterData = GameState.player
	var data: GameData = GameState.data
	var options: Array[Dictionary] = []
	var label := "Adopt a foundling (%d spirit stones)" % Adoption.foundling_donation(data)
	var reason := Adoption.check_foundling(c, GameState.npcs, data)
	if reason != "":
		label += " (%s)" % reason
	options.append({"label": label, "action": GameState.adopt_foundling, "disabled": reason != "", "keep_open": true})
	return options
