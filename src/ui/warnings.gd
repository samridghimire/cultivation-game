class_name Warnings
extends RefCounted
## Plain-text warnings shown before risky choices (WU-086). Pure queries; nothing is blocked.

const FINAL_DEATH := "Your Creation Artifact is empty: if you fall, your life ends."


## The final-death warning when the artifact holds no lives, else "".
## Characters without an artifact (lives -1) are not warned.
static func final_death_warning(c: CharacterData) -> String:
	return FINAL_DEATH if c.artifact_lives == 0 else ""


## `text` with the warning on a new line, or unchanged when there is none.
static func append_to(c: CharacterData, text: String) -> String:
	var w := final_death_warning(c)
	return text if w == "" else (text + "\n" + w if text != "" else w)
