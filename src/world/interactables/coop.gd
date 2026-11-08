class_name Coop
extends Interactable
## CRIT-002: the village hen coop. "Scatter grain" feeds the hens once a day (GameState.feed_hens):
## tomorrow's egg roll is a sure egg and may give two.


func get_options() -> Array[Dictionary]:
	var why := GameState.feed_hens_refusal()
	return [{"label": "Scatter grain (1 Millet or any grain)", "action": GameState.feed_hens, "disabled": why != "", "reason": why}]
