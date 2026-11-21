extends TestCase
## GUIDE-283: Guidance.short_hint never cuts an item or villager name and never ends on a dangling word.


func _names() -> Array[String]:
	var out: Array[String] = []
	for id: String in data().items:
		out.append(String(data().items[id].get("name", id)))
	for id: String in data().npcs:
		out.append(String(data().npcs[id].get("name", id)))
	return out


func _check(line: String, whole_name: String = "") -> void:
	var s := Guidance.short_hint(line, data())
	# A name longer than the limit is kept whole rather than cut.
	assert_true(s.length() <= maxi(Guidance.SHORT_HINT_CHARS, whole_name.length()), "too long (%d): %s" % [s.length(), s])
	var last := s.get_slice(" ", s.get_slice_count(" ") - 1).to_lower()
	assert_false(Guidance.STOP_WORDS.has(last) or Guidance.DANGLING_WORDS.has(last), "dangling word: %s" % s)
	for n in _names():
		# A name that starts inside the result must fit entirely in it.
		var at := line.find(n)
		if at >= 0 and s.find(n.get_slice(" ", 0)) >= 0 and n.contains(" "):
			assert_true(s.contains(n), "partial name '%s' in: %s" % [n, s])


func test_real_lines() -> void:
	assert_eq(Guidance.short_hint("Grow closer: give Hunter Ma the Realgar Wine they like (favor 62/60).", data()).contains("Realgar Wine"), true)
	assert_true(Guidance.short_hint("Grow closer: give Elder Mo the Ancestor Incense they like, on sale here (favor 45/60).", data()).contains("Ancestor Incense"))


func test_liked_gift_lines_for_every_villager() -> void:
	for npc_id: String in data().npcs:
		var npc_name := String(data().npcs[npc_id].get("name", npc_id))
		for item_id: String in data().items:
			if Family.gift_taste(data(), npc_id, item_id) != 1:
				continue
			var item_name := String(data().items[item_id].get("name", item_id))
			_check("Grow closer: give %s the %s they like (favor 45/60)." % [npc_name, item_name], item_name)
			_check("Grow closer: give %s the %s they like, on sale here (favor 45/60)." % [npc_name, item_name], item_name)


func test_tea_lines_for_every_villager() -> void:
	for npc_id: String in data().npcs:
		_check("Grow closer: share tea at %s's (favor 45/60)." % String(data().npcs[npc_id].get("name", npc_id)))


func test_cut_never_ends_inside_a_name() -> void:
	var s := Guidance.short_hint("Visit the market and then give Hunter Ma the Realgar Wine they like very much.", data())
	assert_true(s.length() <= Guidance.SHORT_HINT_CHARS)
	assert_false(s.ends_with("Realgar") or s.ends_with("Hunter") or s.ends_with("give"), s)
	_check("Sell the Ancestor Incense to the merchant in the village market square now.")
