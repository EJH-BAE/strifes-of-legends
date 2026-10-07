extends RefCounted

var max_hp := 1.0
var hp := 1.0
var shown := 1.0
var max_mana := 0.0
var mana := 0.0
var armor := 0.0
var mr := 0.0
var regen := 0.0
var mana_regen := 0.0

func mitigate(raw: float, stat: float) -> float:
	if stat >= 0.0:
		return raw * 100.0 / (100.0 + stat)
	return raw * (2.0 - 100.0 / (100.0 - stat))

func damage(raw: float, kind: String) -> int:
	if raw <= 0.0:
		return 0
	var dealt := raw
	if kind == "physical":
		dealt = mitigate(raw, armor)
	elif kind == "magic":
		dealt = mitigate(raw, mr)
	var rounded := int(round(dealt))
	if rounded < 1:
		rounded = 1
	hp = max(0.0, hp - float(rounded))
	return rounded

func heal(amount: float) -> int:
	if amount <= 0.0 or hp <= 0.0:
		return 0
	var before := hp
	hp = min(max_hp, hp + amount)
	if shown < hp:
		shown = hp
	return int(round(hp - before))

func tick(delta: float) -> void:
	hp = min(max_hp, hp + regen * delta)
	mana = min(max_mana, mana + mana_regen * delta)
	if shown > hp + 0.4:
		shown = lerpf(shown, hp, 1.0 - exp(-3.2 * delta))
	else:
		shown = hp

func hp_text() -> String:
	var cur := 0 if hp <= 0.0 else int(ceil(hp))
	return "%d / %d" % [cur, int(round(max_hp))]

func mana_text() -> String:
	var cur := 0 if mana <= 0.0 else int(ceil(mana))
	return "%d / %d" % [cur, int(round(max_mana))]

func bar_color(team: String) -> Color:
	if team == "red":
		return Color(0.95, 0.18, 0.16)
	if team == "blue":
		return Color(0.22, 0.5, 1.0)
	return Color(0.78, 0.66, 0.28)

func self_test() -> String:
	var phys := mitigate(200.0, 100.0)
	var magic := int(round(mitigate(160.0, 30.0)))
	var neg := mitigate(100.0, -20.0)
	var expect_neg := 100.0 * (2.0 - 100.0 / 120.0)
	if not is_equal_approx(phys, 100.0):
		return "FAIL phys %.3f" % phys
	if magic != 123:
		return "FAIL magic %d" % magic
	if not is_equal_approx(neg, expect_neg):
		return "FAIL neg"
	var v = get_script().new()
	v.max_hp = 1000
	v.hp = 1000
	v.shown = 1000
	v.armor = 100
	var n: int = v.damage(200, "physical")
	if n != 100 or not is_equal_approx(v.hp, 900):
		return "FAIL apply %d %.1f" % [n, v.hp]
	return "OK"
