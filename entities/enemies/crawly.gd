extends KinematicBody

export(bool) var respawns := true
export(bool) var drops_coat := false
export(int) var gem_drop_max = 5
export(int) var health = 15
export(int) var attack_damage = 10
export(float) var run_speed = 7.5
export(float) var lunge_speed = 15.0
export(float) var damaged_speed = 5.0
export(float) var turn_speed_radians = 15.0
export(float) var turn_speed_windup = 5.0
export(float) var turn_speed_attacking = 1.0

onready var anim := $crawly/AnimationPlayer

var coat_scene:PackedScene = load("res://items/coat_pickup.tscn")
var gem_scene:PackedScene = load("res://items/gem_pickup.tscn")

enum AI {
	Idle,
	Alerted,
	Chasing,
	Windup,
	Attacking,
	Damaged,
	Dead
}
var ai = AI.Idle

const GRAVITY := Vector3.DOWN*24
var velocity := Vector3.ZERO

var WINDUP_TIME := .5
var ATTACK_TIME := 0.75
var ALERT_TIME := 2.0
var DAMAGED_TIME := 1.0
var COOLDOWN_TIME := 2.0
var EXTRA_CHASE_TIME := 4.0
var state_timer := 0.0
var cooldown_timer := 0.0
var give_up_timer := 0.0

var target: Spatial
var move_dir: Vector3

var damaged:= []

var coat = null

func _ready():
	if !respawns and Global.is_picked(get_path()):
		queue_free()
		return
	set_state(ai)
	if drops_coat:
		coat = Global.get_coat()
		$crawly/Armature/Skeleton/crawly.material_override = coat.generate_material()

func _physics_process(delta):
	state_timer += delta
	if cooldown_timer > 0:
		cooldown_timer -= delta
	var next = ai
	match ai:
		AI.Idle:
			for b in $awareness.get_overlapping_bodies():
				target = b
				next = AI.Alerted
		AI.Alerted:
			if state_timer > ALERT_TIME:
				next = AI.Chasing
		AI.Chasing:
			if !target:
				next = AI.Idle
			elif !$awareness.overlaps_body(target):
				give_up_timer += delta
				if give_up_timer > EXTRA_CHASE_TIME:
					next = AI.Idle
			elif cooldown_timer <= 0 and $attack_range.overlaps_body(target):
				next = AI.Windup
			else:
				give_up_timer = 0.0
		AI.Windup:
			if state_timer > WINDUP_TIME:
				next = AI.Attacking
		AI.Attacking:
			if state_timer > ATTACK_TIME:
				next = AI.Chasing
		AI.Damaged:
			if state_timer > DAMAGED_TIME:
				next = AI.Chasing
	set_state(next)
	
	match ai:
		AI.Attacking:
			look_at_target(turn_speed_attacking*delta)
			walk(delta, lunge_speed)
			for c in $hurtbox.get_overlapping_bodies():
				if !(c in damaged) and c.has_method("take_damage"):
					c.take_damage(attack_damage, global_transform.basis.z)
				damaged.append(c)
		AI.Chasing:
			look_at_target(turn_speed_radians*delta)
			walk(delta, run_speed)
		AI.Damaged:
			look_at_target(turn_speed_radians*delta)
			velocity.x = move_dir.x
			velocity.z = move_dir.z
			velocity = move_and_slide(velocity + GRAVITY*delta)
		AI.Dead:
			
			var best_normal = Vector3.ZERO
			for c in get_slide_count():
				var n = get_slide_collision(c).normal
				if n.y > best_normal.y:
					best_normal = n
			var gravity := GRAVITY
			if best_normal != Vector3.ZERO:
				gravity = GRAVITY.project(best_normal)
				
			velocity.x = move_dir.x
			velocity.z = move_dir.z
			move_dir *= 0.9
			velocity = move_and_slide(velocity + gravity*delta)
		AI.Idle:
			walk(delta, 0)
		AI.Windup, AI.Alerted:
			look_at_target(turn_speed_windup*delta)
			walk(delta, 0)

func look_at_target(turn_amount: float):
	if !target:
		return
	var forward := global_transform.basis.z
	var desired_f := target.global_transform.origin - global_transform.origin
	desired_f.y = 0
	desired_f = desired_f.normalized()
	var axis = forward.cross(desired_f).normalized()
	if axis.is_normalized():
		var angle = forward.angle_to(desired_f)
		var rot = sign(angle)*min(abs(angle), turn_amount)
		global_rotate(axis, rot)

func walk(delta, speed):
	var hvel = global_transform.basis.z*speed
	velocity.x = hvel.x
	velocity.z = hvel.z
	
	velocity = move_and_slide(velocity + GRAVITY*delta)

func set_state(new_ai):
	if ai == new_ai:
		return
	if ai == AI.Attacking:
		cooldown_timer = COOLDOWN_TIME
	else:
		cooldown_timer = 0
	ai = new_ai
	state_timer = 0
	damaged = []
	match ai:
		AI.Alerted:
			anim.play("Alert")
		AI.Chasing:
			anim.play("Run-loop")
		AI.Damaged:
			anim.play("Damaged")
		AI.Dead:
			collision_layer = 0
			if drops_coat:
				var c = coat_scene.instance()
				c.coat = coat
				c.persistent = false
				get_parent().add_child(c)
				c.global_transform = global_transform
			var gems = int(rand_range(0, gem_drop_max))
			if gems > 0:
				print("Dropping %d gems" % gems)
				var g = gem_scene.instance()
				g.quantity = gems
				get_parent().add_child(g)
				g.global_transform = global_transform
			if !respawns:
				Global.mark_picked(get_path())
			anim.play("Die")
			anim.queue("Dead-loop")
		AI.Idle:
			anim.play("Idle-loop")
		AI.Windup:
			anim.play("Attack")

func take_damage(damage: int, dir: Vector3):
	health -= damage
	move_dir = dir*damaged_speed
	if health <= 0:
		set_state(AI.Dead)
	else:
		set_state(AI.Damaged)
