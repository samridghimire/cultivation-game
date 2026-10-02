class_name Medicine
extends RefCounted
## The Doctor profession's loop: treating your own injuries, paying a clinic,
## and treating patients for income, alignment and Doctor xp.
## Tunables live under "medicine" in data/injuries.json.

const DOCTOR := "doctor"


## Days of healing one self-treatment session gives. Scales with Doctor rank and Spirit.
static func self_treatment_power(c: CharacterData, data: GameData) -> int:
	var per_rank := int(data.medicine.get("heal_days_per_rank", 15))
	return roundi(per_rank * (Professions.rank_of(c, DOCTOR) + 1) * c.attribute("spirit") / 10.0)


## Treat one of your own injuries. Takes self_treatment_days, cuts the
## injury's remaining days by self_treatment_power and trains Doctor.
## Returns {ok, reason, days, days_healed, healed, xp, ranks_gained}.
static func treat_self(c: CharacterData, data: GameData, injury_id: String) -> Dictionary:
	if not c.injuries.has(injury_id):
		return {"ok": false, "reason": "You do not have that injury.", "days": 0, "days_healed": 0, "healed": false, "xp": 0.0, "ranks_gained": 0}
	var days := int(data.medicine.get("self_treatment_days", 7))
	var left := int(c.injuries[injury_id])
	var healed_days := mini(self_treatment_power(c, data), left)
	if healed_days >= left:
		c.injuries.erase(injury_id)
	else:
		c.injuries[injury_id] = left - healed_days
	var xp := days * c.attribute("spirit") / 10.0
	return {"ok": true, "reason": "", "days": days, "days_healed": healed_days, "healed": not c.injuries.has(injury_id), "xp": xp, "ranks_gained": Professions.add_xp(c, data, DOCTOR, xp)}


## Spirit stones a clinic charges to fully heal an injury: its treatment_cost,
## scaled by the fraction of healing still left (at least 1).
static func clinic_cost(c: CharacterData, data: GameData, injury_id: String) -> int:
	var def: Dictionary = data.injuries.get(injury_id, {})
	if def.is_empty() or not c.injuries.has(injury_id):
		return 0
	var fraction := float(c.injuries[injury_id]) / maxf(1.0, float(def.get("heal_days", 1)))
	return maxi(1, ceili(float(def.get("treatment_cost", 0)) * fraction))


## Pay a clinic to heal an injury fully. Returns {ok, reason, cost, days}.
static func visit_clinic(c: CharacterData, data: GameData, injury_id: String) -> Dictionary:
	if not c.injuries.has(injury_id):
		return {"ok": false, "reason": "You do not have that injury.", "cost": 0, "days": 0}
	var cost := clinic_cost(c, data, injury_id)
	if c.item_count("spirit_stone") < cost:
		return {"ok": false, "reason": "The doctor asks %d spirit stones." % cost, "cost": cost, "days": 0}
	c.add_item("spirit_stone", -cost)
	c.injuries.erase(injury_id)
	return {"ok": true, "reason": "", "cost": cost, "days": int(data.medicine.get("clinic_days", 3))}


## Work as a doctor treating patients: more Doctor xp than ordinary work,
## the usual income, and a little alignment for the good done.
## Returns {xp, ranks_gained, income, alignment}.
static func treat_patients(c: CharacterData, data: GameData, days: int) -> Dictionary:
	var result := Professions.work(c, data, DOCTOR, days)
	var bonus_xp: float = result["xp"] * (float(data.medicine.get("patient_xp_multiplier", 1.5)) - 1.0)
	result["ranks_gained"] += Professions.add_xp(c, data, DOCTOR, bonus_xp)
	result["xp"] += bonus_xp
	var alignment := roundi(float(data.medicine.get("patient_alignment_per_month", 3)) * days / Calendar.DAYS_PER_MONTH)
	Alignment.shift(c, data, alignment)
	result["alignment"] = alignment
	return result
