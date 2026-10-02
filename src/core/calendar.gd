class_name Calendar
extends RefCounted
## Fixed in-game calendar: 30-day months, 12-month years. Time is stored as a
## single integer count of days since the game began.

const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const DAYS_PER_YEAR := DAYS_PER_MONTH * MONTHS_PER_YEAR


@warning_ignore("integer_division")
static func year_of(total_days: int) -> int:
	return total_days / DAYS_PER_YEAR + 1


@warning_ignore("integer_division")
static func month_of(total_days: int) -> int:
	return (total_days % DAYS_PER_YEAR) / DAYS_PER_MONTH + 1


static func day_of(total_days: int) -> int:
	return total_days % DAYS_PER_MONTH + 1


static func format_date(total_days: int) -> String:
	return "Year %d, Month %d, Day %d" % [year_of(total_days), month_of(total_days), day_of(total_days)]


## Human-readable duration, e.g. "1 year, 2 months" or "5 days".
@warning_ignore("integer_division")
static func format_duration(days: int) -> String:
	var years := days / DAYS_PER_YEAR
	var months := (days % DAYS_PER_YEAR) / DAYS_PER_MONTH
	var rem_days := days % DAYS_PER_MONTH
	var parts: PackedStringArray = []
	if years > 0:
		parts.append("%d year%s" % [years, "" if years == 1 else "s"])
	if months > 0:
		parts.append("%d month%s" % [months, "" if months == 1 else "s"])
	if rem_days > 0 or parts.is_empty():
		parts.append("%d day%s" % [rem_days, "" if rem_days == 1 else "s"])
	return ", ".join(parts)
