extends NPC

export(NodePath) var climbing_path
export(NodePath) var laili_start
export(NodePath) var player_start
export(NodePath) var plane
export(bool) var on_monument := false

onready var plane_node : Node = (
	get_node(plane) if has_node(plane) else null)

var crashed := false

class LailiGame:
	const title := "Climb to the Top"
	const friendly_id := ""
	const respawn := true
	const dialog_allowed := true
	var id: int
	
	func _init(p_id: int):
		id = p_id
	
	func end():
		pass

onready var climb_game = LailiGame.new(hash(get_path()))

func _ready():
	if on_monument and Global.task_is_complete("strange_girl"):
		global_transform = $"../laili_new_home".global_transform
		custom_entry = "laili_new_home"

func start_climb() -> bool:
	if CustomGames.is_active():
		return false
	# lol
	$"../not_pre_flight/laili_plane_v1".global_transform = (
		$"../laili_plane_start".global_transform)
	if has_node("../not_pre_flight/laili_plane_v1/laili_plane_blanket"):
		$"../not_pre_flight/laili_plane_v1/laili_plane_blanket".queue_free()
	on_monument = false
	custom_entry = "laili_climb"
	CustomGames.start(climb_game)
	var _x = CustomGames.connect("game_completed", self, "_on_game_completed")
	get_node(climbing_path).start()
	global_transform = get_node(laili_start).global_transform
	Global.get_player().teleport_to(get_node(player_start).global_transform)
	return true

func show_plane() -> bool:
	# lol
	$"../not_pre_flight/laili_plane_v1/laili_plane_blanket".queue_free()
	return true

func cancel_climb() -> bool:
	CustomGames.end(false)
	get_node(climbing_path).cancel()
	custom_entry = "laili"
	return true

func _on_game_completed():
	if CustomGames.active_game == climb_game:
		var _x = Global.add_stat("laili/pre_flight")

func fly():
	if has_node(plane):
		var _x = Global.add_stat("laili/flight")
		var res = Global.get_player().get_dialog_viewer().exit()
		Global.save_checkpoint(Global.get_player().get_save_transform())
		get_node(plane).activate()
		return res
	else:
		return false

func reset_flight():
	if plane_node:
		plane_node.reset()
