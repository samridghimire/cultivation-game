class_name Well
extends Interactable
## RV-018: Qingshi's Founder's Old Well (SEASON-008). The drawn well is the solid landmark just beside this bucket place; this place only
## labels it "(n/3)" while the project is unfinished and, once whole, offers the daily "Draw water".

const PROJECT_ID := "well"


## Index of the well in SeasonTasks.project_list (-1 without data).
static func project_index(data: GameData) -> int:
	var list := SeasonTasks.project_list(data)
	for i in list.size():
		if String(list[i].get("id", "")) == PROJECT_ID:
			return i
	return -1


## Stages reached and in total as [stage, total].
static func progress(c: CharacterData, data: GameData) -> Array[int]:
	var idx := project_index(data)
	if idx < 0 or c == null:
		return [0, 0]
	var total := (SeasonTasks.project_list(data)[idx].get("stages", []) as Array).size()
	return [SeasonTasks.project_stage(c, data, idx), total]


static func need_line(stage: int, total: int) -> String:
	if total > 0 and stage >= total:
		return "Clear, cold water sits deep in the old well."
	return "The old well is still being repaired: finish village tasks to restore it."


func label_text() -> String:
	var p := progress(GameState.player, GameState.data)
	return display_name if p[1] == 0 or p[0] >= p[1] else "%s (%d/%d)" % [display_name, p[0], p[1]]


func get_options() -> Array[Dictionary]:
	var p := progress(GameState.player, GameState.data)
	if GameState.player == null or p[1] == 0 or p[0] < p[1]:
		return [{"label": need_line(p[0], p[1]), "action": func(): pass, "disabled": true}]
	var why := SeasonTasks.can_draw(GameState.player, GameState.data, GameState.world_flags, GameClock.total_days)
	return [{"label": "Draw water", "action": GameState.draw_well_water, "disabled": why != "", "reason": why}]


