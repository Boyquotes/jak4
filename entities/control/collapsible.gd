extends KinematicBody

export(float) var damage_force := 0.1
export(Vector3) var falling_rotation := Vector3.ZERO

var falling := false
var velocity := Vector3.ZERO
var angular_velocity := Vector3.ZERO

func _physics_process(delta):
	if !falling:
		set_physics_process(false)
		return
	
	velocity += delta*Vector3.DOWN*9.8
	global_rotate(falling_rotation.normalized(), delta*falling_rotation.length())
	var col := move_and_collide(velocity*delta, false)
	if col and col.collider:
		if !col.collider.is_in_group("push") and col.normal.y > 0.78:
			velocity = Vector3.ZERO
			falling = false
		else:
			velocity = velocity.slide(col.normal)

func take_damage(damage, dir):
	falling = true
	set_physics_process(true)
	velocity = damage*dir*damage_force
