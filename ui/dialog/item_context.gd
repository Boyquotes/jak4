extends Panel

signal item_picked(item, desc)
signal note_picked(tags)
signal context_reply(item)
signal cancelled

onready var coat := $VBoxContainer/coat
onready var bar_context := $VBoxContainer/bar_context
onready var item_list := $item_list
onready var button_box := $VBoxContainer
onready var viewer := $"../viewer"
onready var mini_journal = $"../mini_journal"

var reply_buttons: Array

func _init():
	reply_buttons = []

func _input(event):
	if event.is_action_pressed("dialog_item"):
		_on_cancel_pressed()
	elif event.is_action_pressed("ui_cancel"):
		if item_list.visible:
			item_list.hide()
			button_box.show()
			coat.grab_focus()
		elif mini_journal.visible:
			mini_journal.hide()
			show()
			coat.grab_focus()
		else:
			_on_cancel_pressed()

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			mini_journal.hide()
			item_list.hide()
			button_box.show()
			list_contextual_replies()
			coat.grab_focus()
			set_process_input(is_visible_in_tree())
		elif !mini_journal.is_visible_in_tree():
			item_list.clear()

func list_contextual_replies():
	wipe(reply_buttons)
	for list in viewer.contextual_replies.values():
		for c in list:
			var button:Button = Util.multiline_button(c.text)
			reply_buttons.append(button)
			button_box.add_child_below_node(bar_context, button)
			var _x = button.connect("pressed", self, "context_reply", [c])
	call_deferred("_resize_buttons")
	bar_context.visible = reply_buttons.size() > 0

func _resize_buttons():
	Util.resize_buttons(reply_buttons) 

func context_reply(item: DialogItem):
	hide()
	emit_signal("context_reply", item)

func use_item(id: String, description: ItemDescription = null):
	hide()
	emit_signal("item_picked", id, description)

func use_note(tags: Array):
	hide()
	mini_journal.hide()
	emit_signal("note_picked", tags)

func wipe(nodes: Array):
	for c in nodes:
		c.queue_free()
	nodes.clear()

func _on_coat_pressed():
	use_item("coat")

func _on_cancel_pressed():
	hide()
	emit_signal("cancelled")

func _on_item_pressed(id, item):
	use_item(id, item)

func _on_show_inventory_pressed():
	item_list.view_items(Global.get_fancy_inventory())
	item_list.show()
	button_box.hide()

func _on_show_journal_pressed():
	mini_journal.show()
	hide()

func _on_mini_journal_note_chosen(tags):
	use_note(tags)
