extends KinematicBody

enum AIState {
	Inactive,
	Stalk,
	Chase,
	MoveWindup,
	MoveActive,
	MoveEnd,
}

enum MoveState {
	Locked,
	Ground,
	JumpCharge,
	Jumping,
	Air
}

# Assumed true for now
export(AIState) var ai_state = AIState.Inactive
var move_state = MoveState.Locked

onready var nav := $NavigationAgent
onready var debug_path := $Node/ImmediateGeometry
onready var body:Spatial = $body

var player: PlayerBody
var player_last_origin := Vector3.ZERO

const GRAVITY := Vector3.DOWN*24.0
var velocity := Vector3.ZERO

func _ready():
	var p = Global.get_player()
	if p is PlayerBody:
		player = p
		player_last_origin = player.global_transform.origin
		calculate_path(player_last_origin)

func _physics_process(delta):
	if !player:
		print_debug("Where's the player?")
		return

	var loc = player.global_transform.origin
	var next_pos : Vector3
	if (loc - player_last_origin).length() > 2.0:
		next_pos = calculate_path(loc)
	else:
		next_pos = nav.get_next_location()
	rotate_toward(next_pos, delta)
	var dir := (next_pos - global_transform.origin).normalized()
	var final_pos:Vector3 = nav.get_final_location()
	var final_diff := final_pos - global_transform.origin
	if move_state == MoveState.Jumping:
		dir = (player.global_transform.origin - global_transform.origin).normalized()
		air_move(delta, dir)
		if is_on_floor():
			move_state = MoveState.Ground
	elif final_diff.length() > 2:
		if is_on_floor():
			ground_move(delta, dir)
		else:
			air_move(delta, dir)
	elif !nav.is_target_reachable():
		velocity.y = get_jump_velocity(player.global_transform.origin - global_transform.origin)
		move_state = MoveState.Jumping

func get_jump_velocity(difference: Vector3):
	var diff_y := difference.y
	return 9.0

func ground_move(delta: float, dir: Vector3):
	var gravity: Vector3
	if GRAVITY.dot(get_floor_normal()) >= 0:
		gravity = Vector3.ZERO
	else:
		gravity = GRAVITY.project(get_floor_normal())
	var movement := 4.0*dir
	var vy := velocity.y
	velocity.y = 0
	velocity = velocity.move_toward(movement, 20.0*delta)
	velocity.y += vy
	velocity += delta*gravity
	velocity = move_and_slide(
		velocity, 
		#Vector3.DOWN*0.25,
		Vector3.UP, false, 4, 200.0)

func air_move(delta:float, dir: Vector3):
	dir.y = 0
	var movement := 4.0*dir.normalized()
	var vy := velocity.y
	velocity.y = 0
	velocity = velocity.move_toward(movement, 5.0*delta)
	velocity.y += vy
	velocity += delta*GRAVITY
	velocity = move_and_slide(velocity, Vector3.UP, false, 4, 1.7)

func rotate_toward(point:Vector3, delta:float):
	# TODO: change forward when we get a real mesh
	var forward := -body.global_transform.basis.y
	var desired_f := (point - global_transform.origin)
	desired_f.y = 0
	var angle := forward.angle_to(desired_f)
	if abs(angle) > 0.01:
		var axis := forward.cross(desired_f).normalized()
		if !axis.normalized():
			axis = Vector3.UP
		var rot := sign(angle)*min(abs(angle), delta*10.0)
		body.global_rotate(axis, rot)
	

func calculate_path(loc: Vector3) -> Vector3:
	nav.set_target_location(loc)
	player_last_origin = loc
	var next = nav.get_next_location()
	
	if true:
		debug_path.clear()
		debug_path.begin(Mesh.PRIMITIVE_LINE_STRIP)
		for c in nav.get_nav_path():
			debug_path.add_vertex(c)
		debug_path.end()
	return next
