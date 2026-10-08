extends Node

const Legends = preload("res://scripts/legends.gd")

const BOT_NAMES = [
	"푸른칼날", "안개숲", "별가루", "은빛방패", "마지막빛",
	"붉은창", "그림자숲", "잿빛별", "독침", "핏빛수호",
	"달그림자", "서리창", "바람꽃", "검은돌", "흰여우",
	"노을", "이슬", "가시덤불", "황금눈", "푸른새",
	"안개꽃", "쇠소리", "밤이슬", "돌고래", "햇살",
]

const LANE_PATH := "user://lane.cfg"

var player_legend := "orbel"
var player_role := "mid"
var mode := "ranked"
var turn_limit := 30.0
var blue: Array = []
var red: Array = []
var bans: Array = []
var roster_ready := false
var turns: Array = []
var turn_i := 0
var drafting := false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LANE_PATH) != OK:
		return
	var saved := str(cfg.get_value("lane", "role", "mid"))
	if saved in ["top", "jungle", "mid", "adc", "support"]:
		player_role = saved

func queue(mode_name: String) -> void:
	mode = mode_name
	turn_limit = 15.0 if mode_name == "swift" else 30.0

func set_role(role: String) -> void:
	if role not in ["top", "jungle", "mid", "adc", "support"]:
		return
	player_role = role
	var cfg := ConfigFile.new()
	cfg.set_value("lane", "role", role)
	cfg.save(LANE_PATH)

func player_name() -> String:
	if StrifeAcc.logged_in():
		return StrifeAcc.current()
	return Settings.player_name

func reset() -> void:
	player_legend = "orbel"
	blue.clear()
	red.clear()
	bans.clear()
	roster_ready = false

func begin_series() -> void:
	reset()
	drafting = true
	var roles = ["top", "jungle", "mid", "adc", "support"]
	var mine_at = roles.find(player_role)
	if mine_at < 0:
		mine_at = 2
		player_role = "mid"
	if mode == "duel":
		_duel(player_role)
		return
	var names = BOT_NAMES.duplicate()
	names.shuffle()
	var ni = 0
	for i in 5:
		var mine = i == mine_at
		blue.append({
			"legend": "",
			"ban": "",
			"role": roles[i],
			"username": player_name() if mine else names[ni],
			"player": mine,
			"human": mine,
		})
		if not mine:
			ni += 1
	for i in 5:
		red.append({
			"legend": "",
			"ban": "",
			"role": roles[i],
			"username": names[ni],
			"player": false,
			"human": false,
		})
		ni += 1
	turns.clear()
	turn_i = 0
	var phases = ["ban", "pick"] if mode == "ranked" else ["pick"]
	for phase in phases:
		for i in 5:
			turns.append({"team": "blue", "index": i, "phase": phase})
			turns.append({"team": "red", "index": i, "phase": phase})

func _duel(role: String) -> void:
	blue.append({
		"legend": "",
		"ban": "",
		"role": role,
		"username": player_name(),
		"player": true,
		"human": true,
	})
	red.append({
		"legend": "",
		"ban": "",
		"role": role,
		"username": "결투자",
		"player": false,
		"human": false,
	})
	turns = [{"team": "blue", "index": 0, "phase": "pick"}, {"team": "red", "index": 0, "phase": "pick"}]
	turn_i = 0

func current_turn() -> Dictionary:
	if turn_i < 0 or turn_i >= turns.size():
		return {}
	return turns[turn_i]

func turn_slot() -> Dictionary:
	var turn = current_turn()
	if turn.is_empty():
		return {}
	return slot(str(turn["team"]), int(turn["index"]))

func player_turn() -> bool:
	var who = turn_slot()
	return not who.is_empty() and bool(who.get("player", false))

func taken_ids() -> Dictionary:
	var used = {}
	for row in blue:
		if str(row.get("legend", "")) != "":
			used[str(row["legend"])] = true
		if str(row.get("ban", "")) != "":
			used[str(row["ban"])] = true
	for row in red:
		if str(row.get("legend", "")) != "":
			used[str(row["legend"])] = true
		if str(row.get("ban", "")) != "":
			used[str(row["ban"])] = true
	return used

func commit_turn(legend_id: String) -> bool:
	var turn = current_turn()
	if turn.is_empty():
		return false
	var def = Legends.by_id(legend_id)
	if def.is_empty():
		return false
	if taken_ids().has(legend_id):
		return false
	var team = str(turn["team"])
	var index = int(turn["index"])
	var row = slot(team, index)
	if str(turn["phase"]) == "ban":
		row["ban"] = legend_id
		bans.append(legend_id)
	else:
		row["legend"] = legend_id
		if bool(row.get("player", false)):
			player_legend = legend_id
			player_role = str(row["role"])
	_write_slot(team, index, row)
	turn_i += 1
	if turn_i >= turns.size():
		_seal()
	return true

func choose_auto() -> String:
	var who = turn_slot()
	var role = str(who.get("role", "mid"))
	var used = taken_ids()
	var pool = Legends.by_role(role)
	pool.shuffle()
	for row in pool:
		if not used.has(str(row["id"])):
			return str(row["id"])
	for row in Legends.all():
		if not used.has(str(row["id"])):
			return str(row["id"])
	return "orbel"

func _write_slot(team: String, index: int, row: Dictionary) -> void:
	if team == "blue":
		blue[index] = row
	else:
		red[index] = row

func _seal() -> void:
	drafting = false
	for row in blue:
		if str(row.get("legend", "")) == "":
			row["legend"] = "orbel"
	for row in red:
		if str(row.get("legend", "")) == "":
			row["legend"] = "kaela"
	roster_ready = true

func ensure() -> void:
	if roster_ready and blue.size() == 5 and red.size() == 5:
		return
	fill_default()

func fill_default() -> void:
	reset()
	var used: Dictionary = {}
	var roles = ["top", "jungle", "mid", "adc", "support"]
	var blue_ids = ["changkeut", "soopgil", "byeolbul", "hwasal", "orbel"]
	var red_ids = ["kaela", "noxir", "skael", "dokhwasal", "suho"]
	var blues = ["창끝지기", "안개숲", "별가루", "마지막빛"]
	var reds = ["붉은창", "그림자숲", "잿빛별", "독침", "핏빛수호"]
	for i in 5:
		var bid = blue_ids[i]
		used[bid] = true
		var is_me = i == 4
		blue.append({
			"legend": bid,
			"role": roles[i],
			"username": player_name() if is_me else blues[i],
			"player": is_me,
		})
	for i in 5:
		used[red_ids[i]] = true
		red.append({
			"legend": red_ids[i],
			"role": roles[i],
			"username": reds[i],
			"player": false,
		})
	player_legend = "orbel"
	player_role = "support"
	roster_ready = true

func apply_player_pick(legend_id: String, role: String, banned: Array) -> void:
	reset()
	bans = banned.duplicate()
	var def = Legends.by_id(legend_id)
	if def.is_empty():
		legend_id = "orbel"
		def = Legends.by_id(legend_id)
	player_legend = legend_id
	player_role = role if role != "" and role != "all" else str(def["role"])
	var used: Dictionary = {}
	used[legend_id] = true
	for bid in bans:
		used[str(bid)] = true
	var roles = ["top", "jungle", "mid", "adc", "support"]
	var my_slot = roles.find(player_role)
	if my_slot < 0:
		my_slot = 4
		player_role = "support"
	var names = BOT_NAMES.duplicate()
	names.shuffle()
	var ni = 0
	for i in 5:
		if i == my_slot:
			blue.append({
				"legend": player_legend,
				"role": player_role,
				"username": player_name(),
				"player": true,
			})
			continue
		var pick = _pick_for(roles[i], used)
		used[str(pick["id"])] = true
		blue.append({
			"legend": str(pick["id"]),
			"role": roles[i],
			"username": names[ni],
			"player": false,
		})
		ni += 1
	for i in 5:
		var pick = _pick_for(roles[i], used)
		used[str(pick["id"])] = true
		red.append({
			"legend": str(pick["id"]),
			"role": roles[i],
			"username": names[ni],
			"player": false,
		})
		ni += 1
	roster_ready = true

func _pick_for(role: String, used: Dictionary) -> Dictionary:
	var pool = Legends.by_role(role)
	pool.shuffle()
	for row in pool:
		if not used.has(str(row["id"])):
			return row
	var all = Legends.all().duplicate()
	all.shuffle()
	for row in all:
		if not used.has(str(row["id"])):
			return row
	return Legends.by_id("orbel")

func install_match(mode_name: String, members: Array) -> void:
	queue(mode_name)
	reset()
	var roles = ["top", "jungle", "mid", "adc", "support"]
	var used := {}
	var taken := {}
	blue.clear()
	for i in 5:
		blue.append({"legend": "", "role": roles[i], "username": "", "player": false})
	for member in members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = member
		var role := str(row.get("role", "mid"))
		var idx := roles.find(role)
		if idx < 0 or taken.has(idx):
			idx = -1
			for j in 5:
				if not taken.has(j):
					idx = j
					break
		if idx < 0:
			continue
		taken[idx] = true
		var pick := _pick_for(roles[idx], used)
		used[str(pick.get("id", ""))] = true
		blue[idx] = {
			"legend": str(pick.get("id", "orbel")),
			"role": roles[idx],
			"username": str(row.get("username", "")),
			"player": true,
		}
	var names = BOT_NAMES.duplicate()
	names.shuffle()
	var ni := 0
	for i in 5:
		if bool(blue[i].get("player", false)):
			continue
		var pick := _pick_for(roles[i], used)
		used[str(pick.get("id", ""))] = true
		blue[i] = {
			"legend": str(pick.get("id", "orbel")),
			"role": roles[i],
			"username": names[ni],
			"player": false,
		}
		ni += 1
	red.clear()
	for i in 5:
		var pick := _pick_for(roles[i], used)
		used[str(pick.get("id", ""))] = true
		red.append({
			"legend": str(pick.get("id", "kaela")),
			"role": roles[i],
			"username": names[ni],
			"player": false,
		})
		ni += 1
	roster_ready = true

func install_roster(mode_name: String, roster: Array) -> void:
	queue(mode_name)
	reset()
	var used := {}
	for item in roster:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var role := str(row.get("role", "mid"))
		var legend := str(row.get("legend", ""))
		if legend == "":
			var pick := _pick_for(role, used)
			legend = str(pick.get("id", "orbel"))
			used[legend] = true
		var slot := {
			"legend": legend,
			"role": role,
			"username": str(row.get("username", "")),
			"player": bool(row.get("human", false)),
			"level": int(row.get("level", 1)),
		}
		if str(row.get("team", "blue")) == "red":
			red.append(slot)
		else:
			blue.append(slot)
	roster_ready = blue.size() > 0 and red.size() > 0

func slot(team: String, index: int) -> Dictionary:
	var list = blue if team == "blue" else red
	if index < 0 or index >= list.size():
		return {}
	return list[index]
