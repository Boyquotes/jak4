extends Control

onready var tabs: TabContainer = $tabs
onready var ui = get_parent()

func _input(event):
	if !is_visible_in_tree():
		return
	if !Global.using_gamepad:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("ui_cancel"):
		var t = tabs.get_current_tab_control()
		if tabs.current_tab != 0 or t.level == 0:
			ui.unpause()
		else:
			t.set_level(t.level - 1)
		get_tree().set_input_as_handled()

func set_active(a):
	set_process_input(a)
	if a:
		safe_set_tab(tabs.current_tab)

func next():
	var c = tabs.current_tab + 1
	safe_set_tab(c)

func prev():
	var c = tabs.current_tab - 1
	safe_set_tab(c)

func safe_set_tab(tab):
	if tab < 0 or tab >= tabs.get_tab_count():
		return
	tabs.current_tab = tab

func _on_wardrobe_exited():
	ui.unpause()

func _on_Wardrobe_active(active):
	# TODO: take a screen shot when transitioning back
	$TextureRect.visible = !active
	Global.get_player().set_camera_render(active or !get_tree().paused)
	if !active:
		ui.take_screen_shot()
