class_name Coop
extends Interactable
## CRIT-002: the village hen coop. "Scatter grain" feeds the hens once a day (GameState.feed_hens):
## tomorrow's egg roll is a sure egg and may give two.


func get_options() -> Array[Dictionary]:
	var why := GameState.feed_hens_refusal()
	return [{"label": "Scatter grain (1 Millet or any grain)", "action": _scatter, "disabled": why != "", "reason": why}]


## WU-490: feed the hens, then they crowd in front of the coop and a happy bubble shows over it.
func _scatter() -> bool:
	var ok := GameState.feed_hens()
	if ok and is_inside_tree():
		get_tree().call_group("critter_layer", "refresh")
		var b := EmoteBubble.make("happy")
		b.base_position = Vector2(size.x / 2.0, 0.0)
		add_child(b)
	return ok
