extends KinematicBody
class_name PlayerBody

const GRAVITY := Vector3.DOWN*24

# Movement
const SPEED_WALK := 1.5
const SPEED_RUN := 7.0
const SPEED_CROUCH := 3.0

const SPEED_CLIMB := 5.0
const SPEED_ROLL := 15.0
const SPEED_BONK := 5.0

const MIN_DOT_GROUND := 0.7
const MIN_DOT_SLIDE := 0.12
const MIN_DOT_LEDGE := 0.6

const TIME_COYOTE := 0.1
const TIME_LEDGE_FALL := 0.5
const TIME_CROUCH_JUMP := 0.5
const TIME_BASE_JUMP := 0.25

const JUMP_VEL_BASE := 8.0
const JUMP_VEL_CROUCH := 12.5
const JUMP_VEL_LEDGE := 9.0
const JUMP_VEL_ROLL := 7.0
const JUMP_VEL_ROLL_FORWARD := 16.5

const MIN_SPEED_ROLL := 2.0

const TIME_ROLL_MIN := 0.25
const TIME_ROLL_MAX := 0.5
const TIME_ROLL_MIN_JUMP := 0.3

# Accelerating from zero
const ACCEL_START := 50.0
# Accelerating when moving above some speed
const ACCEL := 20.0
const ACCEL_SLIDE := 10.0
const ACCEL_ROLL := 0.5
# Decelerate against velocity
const DECEL_AGAINST := 45.0
# Decelerate with velocity
const DECEL_WITH := 15.0

const ACCEL_CLIMB := 45.0
const DECEL_CLIMB := 45.0
const ACCEL_STEER_ROLL := 2.5
const ACCEL_DIVE_WINDUP := 75.0

const STAMINA_DRAIN_HANG := 0.5
const STAMINA_DRAIN_CLIMB := 25.0
const STAMINA_DRAIN_MIN := 0.05
const MIN_CLIMB_STAMINA := 10.0

# Combat

const TIME_LUNGE_MAX := 0.6
const TIME_LUNGE_MIN := 0.4
const TIME_LUNGE_MIN_UPPERCUT := 0.2

const TIME_SPIN := 0.7

const TIME_UPPERCUT_WINDUP := 0.25
const TIME_UPPERCUT_MIN := 0.4
const TIME_UPPERCUT_MAX := 0.8

const TIME_DIVE_WINDUP := 0.2
const TIME_DIVE_END_MIN := 0.4
const TIME_DIVE_END_MAX := 0.5

const SPEED_LUNGE := 25.0

const VEL_AIR_SPIN := 3.0
const VEL_UPPERCUT := 10.0
const VEL_DIVE_WINDUP := 4.0

const GRAVITY_BOOST_UPPERCUT := 0.2
const GRAVITY_BOOST_DIVE := 0.5

const STEER_KICK := 5.0
const DECEL_KICK := 75.0

const DAMGE_DIVE_START := 15
const DAMAGE_DIVE_END := 25
const DAMAGE_UPPERCUT := 20
const DAMAGE_LUNGE := 15
const DAMAGE_SPIN := 10
const DAMAGE_ROLL_JUMP := 5

const TIME_DAMAGED := 0.75
const VEL_DAMAGED_H := 5
const VEL_DAMAGED_V := 6

# Nodes
onready var cam_yaw := $camera_rig/yaw
onready var mesh := $jackie
onready var crouch_head := $crouchHeadArea
onready var intention := $intention

onready var ledgeCastLeft := $jackie/leftHandCast
onready var ledgeCastRight := $jackie/rightHandCast
onready var ledgeCastCenter := $jackie/centerCast
onready var ledgeCastCeiling := $jackie/ceilingCast
onready var ledgeCastWall := $jackie/wallCast
onready var ledgeRef := $jackie/reference

onready var lunge_hitbox := $jackie/attack_lunge
onready var spin_hitbox := $jackie/attack_spin
onready var roll_hitbox := $jackie/attack_roll
onready var uppercut_hitbox := $jackie/attack_uppercut
onready var dive_start_hitbox := $jackie/attack_dive_start
onready var dive_end_hitbox := $jackie/attack_dive_end

onready var health_bar := $ui/stats/health/base
onready var stamina_bar := $ui/stats/stamina/base
onready var armor_bar := $ui/stats/health/extra
onready var energy_bar := $ui/stats/stamina/extra

var velocity := Vector3.ZERO
var timer_coyote := 0.0
var timer_state := 0.0

const DEFAULT_MAX_STAMINA := 30.0
const STAMINA_UP_BOOST := 0.15
var max_stamina := DEFAULT_MAX_STAMINA
var stamina_recover := 8.0
var stamina := max_stamina

const DEFAULT_MAX_HEALTH := 50
const HEALTH_UP_BOOST := 0.12
var max_health := DEFAULT_MAX_HEALTH
var health := max_health
var damaged_objects: Array = []

const ARMOR_BOOST := 10.0
var armor := 0
var extra_health := 0.0

const EXTRA_STAMINA_BOOST := 10.0
var energy := 0
var extra_stamina := 0.0

const HEALTH_BAR_DEFAULT_SIZE := 400
const ARMOR_BAR_DEFAULT_SIZE := 80.0

const STAMINA_BAR_DEFAULT_SIZE := 200
const EXTRA_STAMINA_BAR_SIZE := 7

const STAMINA_RECOVERY_BOOST := 0.14
var stamina_factor := 1.0

const DAMAGE_UP_BOOST := 0.15
var damage_factor := 1.0

const JUMP_UP_BOOST := 0.10
var jump_factor := 1.0

const SPEED_UP_BOOST := .10
var speed_factor := 1.0

enum State {
	Ground,
	Fall,
	Slide,
	BaseJump,
	Crouch,
	Roll,
	Climb,
	CrouchJump,
	RollJump,
	RollFall,
	LedgeHang,
	LedgeFall,
	LedgeJump,
	BonkFall,
	LungeKick,
	SpinKick,
	AirSpinKick,
	UppercutWindup,
	Uppercut,
	DiveWindup,
	DiveStart,
	DiveEnd,
	Damaged,
	Locked
}

var state: int = State.Fall
var ground_normal:Vector3 = Vector3.UP

var current_coat: Coat

func _ready():
	$ui/shop.player = self
	set_state(State.Ground)
	if Global.valid_game_state:
		global_transform = Global.game_state.player_transform
		set_current_coat(Global.game_state.current_coat)
	else:
		# Generate three random Common coats
		for _x in range(3):
			var i = -randi()
			var coat = Global.get_coat(i)
			Global.add_coat(coat)
		set_current_coat(Global.game_state.all_coats[0])
	var _x = Global.connect("inventory_changed", self, "update_inventory")
	_x = $ui/dialog_viewer.connect("exited", self, "_on_dialog_exited")
	_x = $ui/dialog_viewer.connect("event_with_source", self, "_on_dialog_event")
	update_inventory()
	health = max_health
	stamina = max_stamina
	update_health()

func _input(event):
	if event.is_action_pressed("debug_randomize_coat"):
		var coat = Global.get_coat(Global.rand64())
		set_current_coat(coat)
		Global.add_coat(coat)
		
func prepare_save():
	Global.game_state.player_transform = global_transform
	Global.game_state.current_coat = current_coat
	assert(Global.game_state.player_transform == global_transform)
	$ui/saveStats/AnimationPlayer.play("save_start")

func complete_save():
	$ui/saveStats/AnimationPlayer.queue("save_complete")

func update_inventory():
	$ui/inventory/gem_count.text = str(Global.count("gem"))
	$ui/inventory/bug_count.text = str(Global.count("bug"))
	$ui/inventory/cap_count.text = str(Global.count("capacitor"))
	
	var health_up :int = Global.count("health_up")
	var stamina_up :int = Global.count("stamina_up")
	
	var h_factor = pow(1.0 + HEALTH_UP_BOOST, health_up)
	var s_factor = pow(1.0 + STAMINA_UP_BOOST, stamina_up)
	
	max_health = DEFAULT_MAX_HEALTH*h_factor
	max_stamina = DEFAULT_MAX_STAMINA*s_factor
	health_bar.max_value = max_health
	health_bar.rect_min_size.x = HEALTH_BAR_DEFAULT_SIZE*h_factor
	
	stamina_bar.max_value = max_stamina
	stamina_bar.rect_min_size.x = STAMINA_BAR_DEFAULT_SIZE*s_factor
	
	stamina_factor = pow(1 + STAMINA_RECOVERY_BOOST, Global.count("stamina_recovery_up"))
	damage_factor = pow(1 + DAMAGE_UP_BOOST, Global.count("damage_up"))
	jump_factor = pow(1 + JUMP_UP_BOOST, Global.count("jump_height_up"))
	speed_factor = pow(1 + SPEED_UP_BOOST, Global.count("move_speed_up"))
	
	var new_armor:int = Global.count("armor")
	if new_armor > armor:
		extra_health += (new_armor - armor)*ARMOR_BOOST
	armor = new_armor
	armor_bar.rect_min_size.x = ARMOR_BAR_DEFAULT_SIZE*armor
	armor_bar.visible = armor > 0 and extra_health > 0
	update_health()
	
	var new_energy = Global.count("stamina_booster")
	if new_energy > energy:
		extra_stamina = new_energy*EXTRA_STAMINA_BOOST
	energy = new_energy
	energy_bar.visible = energy > 0
	
	#debug
	var state_viewer: Control = $ui/debug/game_state
	for c in state_viewer.get_children():
		state_viewer.remove_child(c)
	add_label(state_viewer, "Inventory:")
	for i in Global.game_state.inventory:
		add_label(state_viewer, "\t%s: %d" % [i, Global.count(i)])

func add_label(box: Control, text: String):
	var l := Label.new()
	l.text = text
	box.add_child(l)

func set_current_coat(coat: Coat):
	current_coat = coat
	mesh.show_coat(coat)

func _physics_process(delta):
	if global_transform.origin.y < -1000:
		die()
	timer_state += delta
	if state != State.Climb and state != State.LedgeHang:
		stamina += stamina_factor*stamina_recover*delta
	stamina = clamp(stamina, 0.0, max_stamina)
	
	var movement := Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")
	var desired_velocity: Vector3 = speed_factor*(
		cam_yaw.global_transform.basis.x * movement.x
		+ cam_yaw.global_transform.basis.z * movement.y)
	
	rotate_intention(desired_velocity)
	
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
			elif Input.is_action_just_released("combat_lunge"):
				next_state = State.LungeKick
			elif Input.is_action_just_pressed("combat_spin"):
				next_state = State.SpinKick
			elif $groundArea.get_overlapping_bodies().size() == 0:
				timer_coyote += delta
				if timer_coyote > TIME_COYOTE:
					next_state = State.Fall
			elif best_normal != Vector3.ZERO and best_floor_dot < MIN_DOT_GROUND:
				next_state = State.Slide
			else:
				timer_coyote = 0
		State.Slide:
			if Input.is_action_just_pressed("combat_spin"):
				next_state = State.AirSpinKick
			elif total_stamina() > MIN_CLIMB_STAMINA and Input.is_action_pressed("mv_crouch"):
				next_state = State.Climb
			elif best_floor_dot > MIN_DOT_GROUND:
				next_state = State.Ground
			elif best_floor_dot < MIN_DOT_SLIDE:
				timer_coyote += delta
				if timer_coyote > TIME_COYOTE:
					next_state = State.Fall
			else:
				timer_coyote = 0
		State.BaseJump, State.LedgeJump:
			if Input.is_action_just_pressed("combat_lunge"):
				next_state = State.DiveWindup
			elif Input.is_action_just_pressed("combat_spin"):
				next_state = State.AirSpinKick
			elif timer_state > TIME_BASE_JUMP:
				next_state = State.Fall
		State.Crouch:
			if Input.is_action_just_pressed("mv_jump"):
				next_state = State.CrouchJump
			elif Input.is_action_just_released("combat_lunge"):
				# TODO: HighKick
				next_state = State.UppercutWindup
			elif !Input.is_action_pressed("mv_crouch") and (
				crouch_head.get_overlapping_bodies().size() == 0
			):
				next_state = State.Ground
			elif $groundArea.get_overlapping_bodies().size() == 0:
				timer_coyote += delta
				if timer_coyote > TIME_COYOTE:
					next_state = State.Fall
			elif best_floor_dot < MIN_DOT_GROUND and best_floor_dot > 0:
				if total_stamina() > MIN_CLIMB_STAMINA:
					next_state = State.Climb
				else:
					next_state = State.Slide
			else:
				timer_coyote = 0
		State.CrouchJump:
			if Input.is_action_just_pressed("combat_lunge"):
				next_state = State.DiveWindup
			elif timer_state > TIME_CROUCH_JUMP:
				next_state = State.Fall
		State.Climb:
			drain_stamina(
				(desired_velocity.length() + STAMINA_DRAIN_MIN)
				* STAMINA_DRAIN_CLIMB
				* delta
				* (1.0-best_floor_dot)
			)
			if best_floor_dot > MIN_DOT_GROUND:
				next_state = State.Crouch
			elif best_normal == Vector3.ZERO:
				next_state = State.Fall
			elif total_stamina() <= 0 or !Input.is_action_pressed("mv_crouch"):
				next_state = State.Slide
		State.Roll:
			if (timer_state > TIME_ROLL_MIN_JUMP 
				and Input.is_action_just_pressed("mv_jump")
			):
				next_state = State.RollJump
			elif (timer_state > TIME_ROLL_MIN
				and best_floor_dot < MIN_DOT_SLIDE
			):
				if best_normal != Vector3.ZERO:
					next_state = State.BonkFall
				else:
					timer_coyote += delta
					if timer_coyote > TIME_COYOTE:
						next_state = State.Fall
			else:
				timer_coyote = 0
				if timer_state > TIME_ROLL_MAX:
					next_state = State.Crouch
		State.RollJump:
			if Input.is_action_just_pressed("combat_lunge"):
				next_state = State.DiveWindup
			elif can_ledge_grab():
				next_state = State.LedgeHang
			elif (best_normal != Vector3.ZERO
				and best_floor_dot < MIN_DOT_SLIDE
			):
				ground_normal = best_normal
				next_state = State.BonkFall
			elif timer_state > TIME_CROUCH_JUMP:
				if best_floor_dot > MIN_DOT_GROUND:
					next_state = State.Ground
				elif best_floor_dot > MIN_DOT_SLIDE:
					next_state = State.Slide
				else:
					next_state = State.RollFall
		State.RollFall:
			if Input.is_action_just_pressed("combat_lunge"):
				next_state = State.DiveWindup
			elif can_ledge_grab():
				next_state = State.LedgeHang
			elif best_floor_dot > MIN_DOT_GROUND:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				elif crouch_head.get_overlapping_bodies().size() == 0:
					next_state = State.Ground
			elif best_floor_dot > MIN_DOT_SLIDE:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Climb
				elif crouch_head.get_overlapping_bodies().size() == 0:
					next_state = State.Slide
			elif best_normal != Vector3.ZERO:
					ground_normal = best_normal
					next_state = State.BonkFall
		State.Fall, State.BonkFall:
			if Input.is_action_just_pressed("combat_spin"):
				next_state = State.AirSpinKick
			elif Input.is_action_just_pressed("combat_lunge"):
				next_state = State.DiveWindup
			elif best_floor_dot > MIN_DOT_GROUND:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				else:
					next_state = State.Ground
			elif best_floor_dot > MIN_DOT_SLIDE:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				else:
					next_state = State.Slide
			elif can_ledge_grab():
				next_state = State.LedgeHang
		State.LedgeHang:
			drain_stamina(STAMINA_DRAIN_HANG*delta)
			var intent_dot = mesh.global_transform.basis.z.dot(desired_velocity)
			if Input.is_action_just_pressed("combat_spin"):
				next_state = State.AirSpinKick
			elif Input.is_action_just_pressed("mv_jump"):
				next_state = State.LedgeJump
			elif total_stamina() <= 0 or Input.is_action_just_pressed("mv_crouch") or intent_dot < 0:
				next_state = State.LedgeFall
		State.LedgeFall:
			if Input.is_action_just_pressed("combat_spin"):
				next_state = State.AirSpinKick
			elif Input.is_action_just_pressed("combat_lunge"):
				next_state = State.DiveWindup
			elif best_floor_dot > MIN_DOT_GROUND:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				else:
					next_state = State.Ground
			elif best_floor_dot > MIN_DOT_SLIDE:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				else:
					next_state = State.Slide
			else:
				if timer_state >= TIME_LEDGE_FALL:
					next_state = State.Fall
		State.LungeKick:
			if timer_state >= TIME_LUNGE_MAX:
				next_state = State.Ground
			elif ( timer_state >= TIME_LUNGE_MIN
				and Input.is_action_just_pressed("combat_spin")
			):
				next_state = State.SpinKick
			elif (timer_state >= TIME_LUNGE_MIN_UPPERCUT
				and Input.is_action_just_pressed("mv_jump")
			):
				next_state = State.UppercutWindup
		State.SpinKick:
			if timer_state >= TIME_SPIN:
				next_state = State.Ground
		State.AirSpinKick:
			if best_floor_dot > MIN_DOT_GROUND:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				else:
					next_state = State.Ground
			elif can_ledge_grab():
				next_state = State.LedgeHang
			else:
				if timer_state >= TIME_SPIN:
					next_state = State.Fall
		State.UppercutWindup:
			if timer_state > TIME_UPPERCUT_WINDUP:
				next_state = State.Uppercut
		State.Uppercut:
			if Input.is_action_just_released("combat_lunge"):
				next_state = State.DiveWindup
			elif Input.is_action_just_released("combat_spin"):
				next_state = State.AirSpinKick
			elif timer_state > TIME_UPPERCUT_MIN and best_floor_dot > MIN_DOT_GROUND:
				if Input.is_action_pressed("mv_crouch"):
					next_state = State.Crouch
				else:
					next_state = State.Ground
			elif timer_state > TIME_UPPERCUT_MAX:
				next_state = State.Fall
		State.DiveWindup:
			if timer_state > TIME_DIVE_WINDUP:
				next_state = State.DiveStart
		State.DiveStart:
			if best_floor_dot > MIN_DOT_SLIDE:
				next_state = State.DiveEnd
		State.DiveEnd:
			if timer_state > TIME_DIVE_END_MIN:
				if Input.is_action_just_pressed("combat_lunge"):
					next_state = State.LungeKick
				elif Input.is_action_just_pressed("combat_spin"):
					next_state = State.AirSpinKick
			if timer_state > TIME_DIVE_END_MAX:
				next_state = State.Ground
		State.Damaged:
			if Input.is_action_just_released("combat_lunge"):
				next_state = State.LungeKick
			elif Input.is_action_just_pressed("combat_spin"):
				next_state = State.AirSpinKick
			elif timer_state > TIME_DAMAGED:
				next_state = State.Fall
	set_state(next_state)
	
	match state:
		State.Ground:
			ground_normal = best_normal
			accel(delta, desired_velocity*SPEED_RUN)
		State.Fall, State.LedgeFall:
			accel_air(delta, desired_velocity*SPEED_RUN, ACCEL)
		State.Slide:
			if best_normal != Vector3.ZERO:
				ground_normal = best_normal
			accel_slide(delta, desired_velocity*SPEED_RUN, best_normal)
		State.BaseJump:
			accel_air(delta, desired_velocity*SPEED_RUN, ACCEL_START)
		State.Roll:
			ground_normal = best_normal
			accel(delta, desired_velocity * SPEED_ROLL, ACCEL, ACCEL_STEER_ROLL, 0.0)
		State.RollJump, State.RollFall:
			accel_air(delta, desired_velocity * SPEED_ROLL, ACCEL_ROLL, true)
			damage_point(roll_hitbox, DAMAGE_ROLL_JUMP, global_transform.origin)
		State.BonkFall, State.Damaged:
			accel_air(delta, desired_velocity*SPEED_CROUCH, ACCEL_ROLL)
		State.Crouch:
			ground_normal = best_normal
			accel(delta, desired_velocity*SPEED_CROUCH)
		State.Climb:
			ground_normal = best_normal
			accel_climb(delta, desired_velocity*SPEED_CLIMB)
		State.CrouchJump, State.LedgeJump:
			accel_air(delta, desired_velocity*SPEED_CROUCH, ACCEL)
		State.LedgeHang:
			desired_velocity = Vector3.ZERO
		State.LungeKick:
			rotate_intention(velocity.normalized())
			accel_lunge(delta, desired_velocity*SPEED_LUNGE)
			damage_directed(lunge_hitbox, DAMAGE_LUNGE, get_visual_forward())
		State.SpinKick:
			accel(delta, desired_velocity*SPEED_RUN)
			damage_point(spin_hitbox, DAMAGE_SPIN, global_transform.origin)
		State.AirSpinKick:
			accel_low_gravity(delta, desired_velocity*SPEED_RUN, 0.75)
			damage_point(spin_hitbox, DAMAGE_SPIN, global_transform.origin)
		State.UppercutWindup:
			accel(delta, 0.5*desired_velocity*SPEED_CROUCH)
		State.Uppercut:
			velocity += delta*GRAVITY*GRAVITY_BOOST_UPPERCUT
			accel_air(delta, desired_velocity*SPEED_RUN, ACCEL)
			damage_directed(uppercut_hitbox, DAMAGE_UPPERCUT, Vector3.UP)
		State.DiveWindup:
			accel_air(delta, desired_velocity*SPEED_CROUCH, ACCEL_DIVE_WINDUP)
		State.DiveStart:
			velocity += delta*GRAVITY*GRAVITY_BOOST_DIVE
			accel_air(delta, desired_velocity*SPEED_CROUCH, ACCEL)
			damage_point(dive_start_hitbox, DAMGE_DIVE_START, global_transform.origin)
		State.DiveEnd:
			accel(delta, desired_velocity*SPEED_RUN)
			damage_point(dive_end_hitbox, DAMAGE_DIVE_END, global_transform.origin)
		State.Locked:
			desired_velocity = Vector3.ZERO
	update_visuals(desired_velocity)

func _process(_delta):
	update_stamina()

func update_health():
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.value = health
	armor_bar.max_value = armor*ARMOR_BOOST
	armor_bar.value = extra_health

func update_stamina():
	energy_bar.rect_min_size.x = extra_stamina*EXTRA_STAMINA_BAR_SIZE
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina

func get_visual_forward():
	return mesh.global_transform.basis.z

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
	if ground_normal != Vector3.ZERO:
		gravity = gravity.project(ground_normal.normalized())

	if hvel.length() > SPEED_WALK and desired_velocity != Vector3.ZERO:
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
			(charge - hvel)/SPEED_RUN*charge_accel 
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
	
	velocity = move_and_slide_with_snap(
		velocity,Vector3.DOWN*0.125,Vector3.UP)

func accel_climb(delta: float, desired_velocity: Vector3):
	var gravity := GRAVITY
	if ground_normal != Vector3.ZERO:
		var axis = Vector3.UP.cross(ground_normal).normalized()
		var angle = Vector3.UP.angle_to(ground_normal)
		if axis.is_normalized():
			desired_velocity = desired_velocity.rotated(axis, angle)
		gravity = GRAVITY.project(ground_normal)
		
	var charge_accel = ACCEL_CLIMB
	var charge: Vector3
	var steer: Vector3
	if velocity != Vector3.ZERO:
		charge = desired_velocity.project(velocity.normalized())
		steer = desired_velocity.slide(velocity.normalized())
		if (charge.dot(velocity) > 0 
			and charge.length() < velocity.length()
		):
			charge_accel = DECEL_CLIMB
		else:
			charge_accel = ACCEL_CLIMB
	else:
		charge = desired_velocity
		steer = Vector3.ZERO
	velocity += delta*(
		(charge - velocity)/SPEED_RUN*charge_accel 
		+ (steer*ACCEL_CLIMB) 
		+ gravity )
	velocity = move_and_slide_with_snap(
		velocity + delta*gravity,Vector3.DOWN*0.125,Vector3.UP)

func accel_air(delta: float, desired_velocity: Vector3, accel: float, ignore_slide := false):
	var hvel := Vector3(velocity.x, 0, velocity.z).move_toward(desired_velocity, accel*delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	velocity += GRAVITY*delta
	var pre_slide_vel := velocity
	velocity = move_and_slide(velocity)
	if pre_slide_vel.y <= 0:
		velocity.y = clamp(velocity.y, pre_slide_vel.y, 0.0)
	else:
		velocity.y = max(velocity.y, pre_slide_vel.y)
	if ignore_slide:
		velocity = pre_slide_vel

func accel_low_gravity(delta, desired_velocity, gravity_factor):
	var hvel := Vector3(velocity.x, 0, velocity.z).move_toward(desired_velocity, ACCEL*delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	velocity += gravity_factor*GRAVITY*delta
	var pre_slide_vel := velocity
	velocity = move_and_slide(velocity)
	velocity.y = min(pre_slide_vel.y, velocity.y)

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

func accel_lunge(delta, desired_velocity):
	var hvel = velocity
	hvel.y = 0
	desired_velocity.y = 0
	hvel = hvel.move_toward(desired_velocity, STEER_KICK*delta)
	var v2 := move_and_slide(velocity + GRAVITY*delta)
	velocity = velocity.move_toward(Vector3.ZERO, DECEL_KICK*delta)
	velocity.y = min(velocity.y, v2.y)

func is_grounded():
	return ( state == State.Ground
		or state == State.Slide
		or state == State.Roll
		or state == State.Crouch)

func cannot_flinch():
	return ( state == State.DiveWindup
		or state == State.DiveStart
		or state == State.UppercutWindup)

func can_ledge_grab() -> bool:
	if ((ledgeCastCeiling.is_colliding() 
		and ledgeCastCeiling.get_collision_normal().y < 0)
		or ( 
			ledgeCastWall.is_colliding()
			and ledgeCastWall.get_collision_normal().y < MIN_DOT_LEDGE
	)):
		return false
	var left:bool = (
		ledgeCastLeft.is_colliding()
		and ledgeCastLeft.get_collision_normal().y > MIN_DOT_LEDGE)
	var right:bool = (
		ledgeCastRight.is_colliding()
		and ledgeCastRight.get_collision_normal().y > MIN_DOT_LEDGE)
	var center:bool = (
		ledgeCastCenter.is_colliding()
		and ledgeCastCenter.get_collision_normal().y > MIN_DOT_LEDGE)
	return center and (left or right) 

func snap_to_ledge():
	var change = ledgeCastCenter.get_collision_point() - ledgeRef.global_transform.origin
	global_translate(change)

func should_slow_follow():
	return state == State.LungeKick or state == State.RollJump

func update_visuals(input_dir: Vector3, var flip = false):
	var crouching = state == State.Crouch or state == State.Climb
	var climbing = state == State.Climb
	var vs = velocity/(SPEED_CROUCH if crouching else SPEED_RUN)
	var vis_vel = lerp(
		vs,
		input_dir,
		0.5)
	if flip:
		vis_vel = -vis_vel
		
	mesh.set_movement_animation(
		vs.length(), 
		crouching, climbing)
	
	if abs(vis_vel.x) + abs(vis_vel.z) > 0.1 and input_dir != Vector3.ZERO:
		rotate_mesh(Vector3(vis_vel.x, 0, vis_vel.z).normalized())

func rotate_mesh(target: Vector3):
	var forward = mesh.global_transform.basis.z
	var axis = forward.cross(target).normalized()
	if axis.is_normalized():
		var angle = forward.angle_to(target)
		mesh.global_rotate(axis, angle)

func rotate_intention(dir: Vector3):
	dir.y = 0
	dir = dir.normalized()
	if dir != Vector3.ZERO:
		intention.global_transform = intention.global_transform.looking_at(
			intention.global_transform.origin + dir,
			Vector3.UP
		)

func damage_point(area: Area, damage: int, point: Vector3):
	for g in area.get_overlapping_bodies():
		var damage_dir = g.global_transform.origin - point
		damage_dir = damage_dir.normalized()
		damage(g, damage, damage_dir)

func damage_directed(area: Area, damage: int, damage_dir: Vector3):
	for g in area.get_overlapping_bodies():
		damage(g, damage, damage_dir)

func damage(node: Node, damage: int, dir: Vector3):
	if node in damaged_objects:
		return
	damaged_objects.append(node)
	if node.has_method("take_damage"):
		node.take_damage(damage_factor*damage, dir)

func take_damage(damage: int, direction: Vector3):
	if state == State.Locked:
		return
	if extra_health:
		var diff = extra_health - damage
		if diff > 0:
			damage = 0
			extra_health = diff
		else:
			extra_health = 0
			damage = -diff
		var new_armor = ceil(extra_health/ARMOR_BOOST)
		Global.add_item("armor", new_armor - armor)
		armor = new_armor
	health -= damage
	update_health()
	if health <= 0:
		die()
		return
	velocity = VEL_DAMAGED_H*direction
	if !cannot_flinch():
		set_state(State.Damaged)

func die():
	var _x = Global.add_stat("player_death")
	# TODO: Animation and fadeout, then queue respawn
	respawn()

func respawn():
	velocity = Vector3.ZERO
	$ui/fade/AnimationPlayer.play("fadein")
	heal()
	global_transform.origin = Global.checkpoint_position + Vector3.UP

func heal():
	health = max_health
	stamina = max_stamina
	extra_stamina = energy*EXTRA_STAMINA_BOOST
	extra_health = armor*ARMOR_BOOST
	update_health()

func drain_stamina(amount):
	var diff = stamina - amount
	if diff < 0:
		extra_stamina += diff
		extra_stamina = max(extra_stamina, 0)
		energy = int(ceil(extra_stamina/EXTRA_STAMINA_BOOST))
		stamina = 0
	else:
		stamina = diff

func total_stamina():
	return extra_stamina + stamina

func can_talk():
	return state == State.Ground

func start_dialog(source: Node, sequence: Resource, speaker: Node):
	$ui/dialog_viewer.start(source, sequence, speaker)
	$camera_rig.play_animation("dialog_start")
	lock()

func _on_dialog_exited():
	$ui/dialog_viewer.end()
	$camera_rig.play_animation("dialog_end")
	unlock()

func _on_dialog_event(id: String, source: Node):
	match id:
		"open_shop":
			$ui/stats.show()
			$ui/inventory.show()
			$ui/inventory/AnimationPlayer.play("show_for_shop")
			$ui/shop.start_shopping(source)

func stop_shopping():
	$ui/stats.hide()
	$ui/inventory.hide()
	$ui/inventory/AnimationPlayer.play("RESET")
	$ui/shop.hide()
	$ui/dialog_viewer.resume()

func wardrobe_lock():
	lock()
	$camera_rig.play_animation("wardrobe_lock")

func wardrobe_unlock():
	unlock()
	$camera_rig.play_animation("wardrobe_unlock")

func lock():
	set_process_input(false)
	set_state(State.Locked)
	$ui/stats.hide()
	$ui/inventory.hide()

func unlock():
	set_process_input(true)
	$unlock_timer.start()
	$ui/stats.show()
	$ui/inventory.show()

func _on_unlock_timer_timeout():
	set_state(State.Ground)

func set_state(next_state: int):
	if state == next_state:
		return
	timer_coyote = 0.0
	timer_state = 0.0
	$crouching_col.disabled = true
	$standing_col.disabled = false
	
	match next_state:
		State.Fall, State.LedgeFall:
			mesh.transition_to("Fall")
		State.BaseJump:
			velocity.y = jump_factor*JUMP_VEL_BASE
			mesh.transition_to("BaseJump")
		State.Ground:
			mesh.transition_to("Ground")
		State.Slide:
			pass
		State.Crouch, State.Climb:
			$crouching_col.disabled = false
			$standing_col.disabled = true
			mesh.transition_to("Ground")
		State.CrouchJump:
			velocity.y = jump_factor*JUMP_VEL_CROUCH
			mesh.transition_to("BaseJump")
		State.LedgeHang:
			mesh.transition_to("LedgeGrab")
			snap_to_ledge()
			velocity = Vector3.ZERO
		State.LedgeJump:
			velocity.y += jump_factor*JUMP_VEL_LEDGE
			mesh.transition_to("BaseJump")
		State.Roll:
			$crouching_col.disabled = false
			$standing_col.disabled = true
			mesh.transition_to("Roll")
		State.RollJump:
			$crouching_col.disabled = false
			$standing_col.disabled = true
			var dir = mesh.global_transform.basis.z
			velocity = speed_factor*dir*JUMP_VEL_ROLL_FORWARD
			velocity.y = jump_factor*JUMP_VEL_ROLL
			
			mesh.transition_to("RollJump")
		State.BonkFall:
			mesh.transition_to("Fall")
			var dir = ground_normal
			dir.y = 0.1
			dir = dir.normalized()
			velocity = speed_factor*dir*SPEED_BONK
		State.LungeKick:
			damaged_objects = []
			var dir = get_visual_forward()
			velocity = speed_factor*dir*SPEED_LUNGE
			mesh.transition_to("LungeKickRight")
		State.SpinKick, State.AirSpinKick:
			damaged_objects = []
			velocity.y = jump_factor*VEL_AIR_SPIN
			mesh.transition_to("SpinKickLeft")
			$jackie/attack_spin/AnimationPlayer.play("spin")
		State.UppercutWindup:
			mesh.transition_to("Uppercut")
		State.Uppercut:
			damaged_objects = []
			velocity.y = jump_factor*VEL_UPPERCUT
		State.DiveWindup:
			velocity.y = VEL_DIVE_WINDUP
			mesh.transition_to("DiveStart")
		State.DiveStart:
			damaged_objects = []
		State.DiveEnd:
			damaged_objects = []
			mesh.transition_to("DiveEnd")
		State.Damaged:
			velocity.y = speed_factor*VEL_DAMAGED_V
			mesh.transition_to("Fall")
		State.Locked:
			mesh.transition_to("Ground")
			velocity = Vector3.ZERO
	state = next_state
	$ui/debug/stats/a1.text = "State: %s" % State.keys()[state]
