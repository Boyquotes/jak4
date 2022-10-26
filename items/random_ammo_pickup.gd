extends Spatial

export(bool) var generate_on_ready := false
export(bool) var regenerate_on_death := false
export(bool) var ignore_parent := false

func _ready():
	if generate_on_ready:
		if regenerate_on_death:
			var _x = Global.get_player().connect("died", self, "generate")
		generate()
	elif !ignore_parent:
		var p = get_parent()
		if p is Door:
			p.connect("opened", self, "generate")

func generate():
	var a = AmmoSpawner.get_random_ammo()
	if a:
		add_child(a)
		a.global_transform = global_transform
		a.show()
		
