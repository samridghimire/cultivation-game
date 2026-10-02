extends Interactable
## A wild place to search for herbs, treasures and trouble. Encounters come
## from data/encounters.json, chosen by tag.

## Encounter tags for this spot. Empty = the region's encounter_tags.
@export var explore_tags: Array = []


func get_options() -> Array[Dictionary]:
	return [{"label": "Explore", "action": GameState.explore.bind(explore_tags), "keep_open": true}]
