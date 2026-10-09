extends SceneTree
## Log-noise sim (QA-059): how many message-log lines a curious player sees per topic per
## month, and which line templates repeat the most (names and digits stripped).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/log_noise.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")

var _bus: Node
var _gs: Node
var _clock: Node
var _topic_counts := {}
var _template_counts := {}
var _by_month := {}  # topic -> {month -> count}


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _on_message(text: String, _category: String) -> void:
	var topic := "(none)"
	if _bus.history.size() > 0 and String(_bus.history.back()["topic"]) != "":
		topic = String(_bus.history.back()["topic"])
	_topic_counts[topic] = int(_topic_counts.get(topic, 0)) + 1
	var month: int = _clock.total_days / Calendar.DAYS_PER_MONTH
	var key := "%s#%d" % [topic, month]
	_by_month[key] = int(_by_month.get(key, 0)) + 1
	var tpl := _template(text)
	_template_counts[tpl] = int(_template_counts.get(tpl, 0)) + 1


func _template(text: String) -> String:
	var out := text
	var names: Array[String] = []
	for npc_id: String in _gs.npcs:
		names.append(String(_gs.npcs[npc_id].name))
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for n in names:
		if n != "":
			out = out.replace(n, "<name>")
	var re := RegEx.new()
	re.compile("\\d+")
	return re.sub(out, "N", true)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 5
	var months := int(args[1]) if args.size() > 1 else 12
	_gs = root.get_node("GameState")
	_clock = root.get_node("GameClock")
	_bus = root.get_node("EventBus")
	_bus.message_posted.connect(_on_message)
	print("Log noise: %d seeds, %d months, curious player" % [seeds, months])
	var total_months := 0
	for s in range(1, seeds + 1):
		var r: Dictionary = FirstHour.play(_gs, _clock, s, months, true)
		total_months += r["month_lines"].size()
		_gs.end_session()
	total_months = maxi(1, total_months)
	print("Posts per month by topic:")
	var topics: Array = _topic_counts.keys()
	topics.sort_custom(func(a: String, b: String) -> bool: return _topic_counts[a] > _topic_counts[b])
	for t: String in topics:
		var peak := 0
		for key: String in _by_month:
			if key.begins_with(t + "#"):
				peak = maxi(peak, int(_by_month[key]))
		print("  %-12s %6.1f/month (busiest month in any seed: %d)" % [t, float(_topic_counts[t]) / total_months, peak])
	print("Most repeated line templates (per month, averaged):")
	var tpls: Array = _template_counts.keys()
	tpls.sort_custom(func(a: String, b: String) -> bool: return _template_counts[a] > _template_counts[b] or (_template_counts[a] == _template_counts[b] and a < b))
	for i in mini(10, tpls.size()):
		print("  %5.2f  %s" % [float(_template_counts[tpls[i]]) / total_months, String(tpls[i]).left(110)])
	quit()
