extends Node

onready var entrance := $entrance
onready var mom_door := $door2

onready var dialog_collision := $dialog_zone/CollisionShape

var active := false

func activate_scanner():
	if active:
		return
	Global.add_stat("medium_activated")
	active = true
	dialog_collision.disabled = true
	mom_door.add_power(1)

func _on_entrance_body_entered(_b):
	if !active:
		return
	active = false
	dialog_collision.disabled = false
	Global.add_stat("medium_deactivated")
	mom_door.add_power(-1)
