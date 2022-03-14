extends KinematicBody
class_name PlayerBody

const RUN_SPEED := 7.0
const WALKING_SPEED := 1.5
const GRAVITY := Vector3.DOWN*24

const MIN_GROUND_DOT := 0.7
const MIN_SLIDE_DOT := 0.12

const COYOTE_TIME := 0.1
var coyote_timer := 0.0

const BASE_JUMP_TIME := 0.25
const BASE_JUMP_VEL := 10.0
const CROUCH_JUMP_VEL := 14.5
const ROLL_JUMP_VEL := 7.0
const ROLL_JUMP_LURCH := 5.0
const ROLL_JUMP_STEER := 2.5
const CROUCH_JUMP_TIME := 0.5
var air_timer := 0.0

const MIN_SPEED_ROLL := 2.0

const CROUCH_SPEED := 2.0
const ROLL_SPEED := 15.0
const ROLL_TIME := 0.5
var roll_timer := 0.0

# Accelerating from zero
const ACCEL_START := 50.0
# Accelerating when moving above some speed
const ACCEL := 20.0
const ACCEL_SLIDE := 10.0
# Decelerate against velocity
const DECEL_AGAINST := 45.0
# Decelerate with velocity
const DECEL_WITH := 15.0

onready var cam_yaw := $camera_rig/yaw
onready var mesh := $jackie

var velocity := Vector3.ZERO

enum State {
	Ground,
	Fall,
	Slide,
	BaseJump,
	Crouch,
	Roll,
	CrouchJump,
	RollJump
}

var state: int = State.Ground
var ground_normal:Vector3 = Vector3.UP

func _physics_process(delta):
	var movement := Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")
	
	var desired_velocity: Vector3 = (
		cam_yaw.global_transform.basis.x * movement.x
		+ cam_yaw.global_transform.basis.z * movement.y)
	
	var best_floor_dot := -1.0
	var best_normal := Vector3.ZERO
	for c in range(get_slide_count()):
		var col := get_slide_collision(c)
		var normal := col.normal
		var dot := normal.dot(Vector3.UP)
		if dot > best_floor_dot:
			best_floor_dot = dot
			best_normal = normal
	$ui/debug/stats/a2.text = "Floor Dot: %f" % best_floor_dot
	
	var next_state := state
	match state:
		State.Ground:
			if Input.is_action_just_pressed("mv_jump"):
				next_state = State.BaseJump
			elif Input.is_action_pressed("mv_crouch"):
				if velocity.length() > MIN_SPEED_ROLL:
					next_state = State.Roll
				else:
					next_state = State.Crouch
			elif !$groundArea.get_overlapping_bodies().size() > 0:
				coyote_timer += delta
				if coyote_timer > COYOTE_TIME:
					next_state = State.Fall
			elif best_normal != Vector3.ZERO and best_floor_dot < MIN_GROUND_DOT:
				next_state = State.Slide
			else:
				coyote_timer = 0
		State.Slide:
			if best_floor_dot > MIN_GROUND_DOT:
				next_state = State.Ground
			elif best_floor_dot < MIN_SLIDE_DOT:
				coyote_timer += delta
				if coyote_timer > COYOTE_TIME:
					next_state = State.Fall
			else:
				coyote_timer = 0
		State.BaseJump:
			air_timer += delta
			if air_timer > BASE_JUMP_TIME:
				next_state = State.Fall
		State.CrouchJump, State.RollJump:
			air_timer += delta
			if air_timer > CROUCH_JUMP_TIME:
				next_state = State.Fall
		State.Fall:
			if best_floor_dot > MIN_GROUND_DOT:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				else:
					next_state = State.Ground
			elif best_floor_dot > MIN_SLIDE_DOT:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				else:
					next_state = State.Slide
		State.Crouch:
			if Input.is_action_just_pressed("mv_jump"):
				next_state = State.CrouchJump
			elif !Input.is_action_pressed("mv_crouch"):
				next_state = State.Ground
			elif best_floor_dot < MIN_SLIDE_DOT:
				next_state = State.Fall
		State.Roll:
			if Input.is_action_just_pressed("mv_jump"):
				next_state = State.RollJump
			elif best_floor_dot < MIN_SLIDE_DOT:
				coyote_timer += delta
				if coyote_timer > COYOTE_TIME:
					next_state = State.Fall
			else:
				coyote_timer = 0
				roll_timer += delta
				if roll_timer > ROLL_TIME:
					next_state = State.Crouch
	set_state(next_state)
	
	match state:
		State.Ground:
			ground_normal = best_normal
			accel(delta, desired_velocity*RUN_SPEED)
		State.Fall:
			accel(delta, desired_velocity*RUN_SPEED)
		State.Slide:
			if best_normal != Vector3.ZERO:
				ground_normal = best_normal
			accel_slide(delta, desired_velocity*RUN_SPEED, best_normal)
		State.BaseJump:
			accel(delta, desired_velocity*RUN_SPEED)
		State.Roll, State.RollJump:
			accel(delta, desired_velocity * ROLL_SPEED, ACCEL, ROLL_JUMP_STEER, 0.0)
		State.Crouch, State.CrouchJump:
			accel(delta, desired_velocity*CROUCH_SPEED)
	update_visuals()

func update_visuals():
	mesh.set_movement_animation(velocity.length()/CROUCH_SPEED, state == State.Crouch)
	if abs(velocity.x) + abs(velocity.z) > 0.01:
		var target := Vector3(velocity.x, 0, velocity.z).normalized()
		var forward = mesh.global_transform.basis.z
		var axis = forward.cross(target).normalized()
		if axis.is_normalized():
			var angle = forward.angle_to(target)
			mesh.global_rotate(axis, angle)


func accel(delta: float, desired_velocity: Vector3, accel_normal: float = ACCEL, steer_accel: float = ACCEL, decel_factor: float = 1):
	var hvel := velocity
	hvel.y = 0
	var hdir := hvel.normalized()
	
	$ui/debug/stats/a3.text = "DV: (%f, %f, %f)" % [
		desired_velocity.x,
		desired_velocity.y,
		desired_velocity.z
	]
	var gravity = GRAVITY
	if state == State.Ground and ground_normal != Vector3.ZERO:
		gravity = gravity.project(ground_normal.normalized())

	if hvel.length() > WALKING_SPEED and desired_velocity != Vector3.ZERO:
		var charge_accel = accel_normal
		# Direction parellel to current (horizontal) velocity
		var charge := desired_velocity.project(hdir)
		# Direction perpendicular to (horizontal) velocity
		var steer := desired_velocity.slide(hdir)
		if charge.dot(hvel) > 0:
			# Moving in the same direction
			if charge.length() < velocity.length():
				# Decelerating
				charge_accel = DECEL_WITH*decel_factor
			else:
				charge_accel = accel_normal
		else:
			charge_accel = DECEL_AGAINST*decel_factor
		velocity += delta*(
			(charge - hvel)/RUN_SPEED*charge_accel 
			+ (steer*steer_accel) 
			+ gravity )
	else:
		if desired_velocity.length_squared() < 0.05:
			hvel = hvel.move_toward(desired_velocity, DECEL_AGAINST*decel_factor)
		else:
			hvel = hvel.move_toward(desired_velocity, ACCEL_START)
		velocity.x = hvel.x
		velocity.z = hvel.z
		velocity += delta*gravity
	
	if state == State.Ground:
		velocity = move_and_slide_with_snap(velocity, Vector3.DOWN*0.125, Vector3.UP)
	else:
		velocity = move_and_slide(velocity)

func accel_slide(delta: float, desired_velocity: Vector3, wall_normal: Vector3):
	if desired_velocity.dot(wall_normal) < 0:
		desired_velocity = desired_velocity.slide(wall_normal)
	var angle = Vector3.UP.angle_to(wall_normal)
	var axis = Vector3.UP.cross(wall_normal).normalized()
	if axis != Vector3.ZERO:
		desired_velocity = desired_velocity.rotated(axis, angle)
	desired_velocity.y = -1
	
	var hvel := velocity
	hvel = hvel.move_toward(desired_velocity, ACCEL_SLIDE*delta)
	
	velocity = Vector3(
		hvel.x,
		min(hvel.y, velocity.y),
		hvel.z)
	velocity = move_and_slide(velocity + delta*GRAVITY)

func set_state(next_state: int):
	if state == next_state:
		return
	coyote_timer = 0.0
	roll_timer = 0.0
	air_timer = 0.0
	match next_state:
		State.Fall:
			mesh.transition_to("Fall")
		State.BaseJump:
			velocity.y = BASE_JUMP_VEL
			mesh.transition_to("BaseJump")
		State.Ground,State.Crouch:
			mesh.transition_to("Ground")
		State.Slide:
			pass
		State.Roll:
			mesh.transition_to("Roll")
		State.CrouchJump:
			velocity.y = CROUCH_JUMP_VEL
			mesh.transition_to("BaseJump")
		State.RollJump:
			velocity.y = ROLL_JUMP_VEL
			velocity += -cam_yaw.global_transform.basis.z*ROLL_JUMP_LURCH
			mesh.transition_to("RollJump")
	state = next_state
	$ui/debug/stats/a1.text = "State: %s" % State.keys()[state]

func is_grounded():
	return ( state == State.Ground
		or state == State.Slide
		or state == State.Roll
		or state == State.Crouch)
