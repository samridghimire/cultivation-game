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


static func season_of(total_days: int) -> String:
	var month := month_of(total_days)
	if month <= 3:
		return "Spring"
	if month <= 6:
		return "Summer"
	if month <= 9:
		return "Autumn"
	return "Winter"


## Days remaining after today before the season changes (0 on its last day).
static func days_left_in_season(total_days: int) -> int:
	var month_in_season := (month_of(total_days) - 1) % 3
	return (2 - month_in_season) * DAYS_PER_MONTH + (DAYS_PER_MONTH - day_of(total_days))


## Subtle world tint multiplier for a season (close to white).
static func season_tint(season: String) -> Color:
	match season:
		"Spring":
			return Color(1.0, 1.0, 0.98)
		"Summer":
			return Color(1.0, 0.98, 0.92)
		"Autumn":
			return Color(1.0, 0.93, 0.85)
		"Winter":
			return Color(0.88, 0.92, 1.0)
	return Color.WHITE


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
