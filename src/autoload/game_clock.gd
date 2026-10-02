extends Node
## World time. Time only moves when actions take time (cultivating, working...).

signal days_advanced(days: int)
signal year_changed(year: int)

var total_days := 0


func advance(days: int) -> void:
	if days <= 0:
		return
	var old_year := Calendar.year_of(total_days)
	total_days += days
	days_advanced.emit(days)
	var new_year := Calendar.year_of(total_days)
	if new_year != old_year:
		year_changed.emit(new_year)


func reset() -> void:
	total_days = 0


func date_string() -> String:
	return Calendar.format_date(total_days)


func to_dict() -> Dictionary:
	return {"total_days": total_days}


func from_dict(d: Dictionary) -> void:
	total_days = int(d.get("total_days", 0))
