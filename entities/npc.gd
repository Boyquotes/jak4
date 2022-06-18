extends KinematicBody
class_name NPC

export(Resource) var dialog
export(String) var visual_name := "Villager"
export(float) var model_scale := 1.0
export(String) var friendly_id := ""
export(Mesh) var accessory: Mesh
export(bool) var sitting := false
onready var anim := $lil_man/AnimationPlayer

const coat_dialog := "res://dialog/_coat.dialog"

func _ready():
	if sitting:
		anim.play("Sitting-loop")
	else:
		anim.play("Idle-loop")
	$lil_man.scale = Vector3(model_scale, model_scale, model_scale)
	anim.seek(rand_range(0, anim.current_animation_length))
	if !dialog:
		$dialog.queue_free()

func _on_dialog_body_entered(body):
	if body is PlayerBody and body.can_talk():
		body.start_dialog(self, dialog, self)

func get_coat() -> Coat:
	return Global.stat($lil_man.coat_stat())

func set_coat(coat: Coat):
	$lil_man.show_coat(coat)
	return Global.set_stat($lil_man.coat_stat(), coat)

func start_coat_trade(player: PlayerBody):
	if !dialog:
		player.start_dialog(self, load(coat_dialog), self)
	else:
		player.start_dialog(self, dialog, self, "_coat")
