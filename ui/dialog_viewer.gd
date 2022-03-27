extends Control

signal exited
signal event(id)
signal event_with_source(id, source)

var player: Node
var main_speaker: Node
var source_node: Node
var last_speaker: String

var current_item : DialogItem
var sequence: Resource
var now: Dictionary

export(Font) var speaker_font
export(Font) var narration_font
export(Font) var player_font

export(Color) var speaker_color := Color.whitesmoke
export(Color) var narration_color := Color.dimgray
export(Color) var player_color := Color.deeppink

onready var replies := $vbox/replies
onready var messages := $vbox/messages/list

const RESULT_SKIP := {"result":"skip"}
const RESULT_PAUSE := {"result":"pause"}
const RESULT_END := {"result":"end"}

var r_otherwise_if := RegEx.new()
var r_interpolate := RegEx.new()

var otherwise := false
var talked := 0
var skip_reply := false
var discussed := {}
var is_exiting := false
# Stack of IDs for DialogItems
var call_stack:= []

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		fast_exit()
	elif current_item.type != DialogItem.Type.REPLY and event.is_action_pressed("ui_accept"):
		get_next()

func _process(_delta):
	var scr = $vbox/messages
	scr.scroll_vertical = scr.get_v_scrollbar().max_value

func _ready():
	var _x = r_otherwise_if.compile("^\\s*otherwise\\s+if\\s+")
	_x = r_interpolate.compile("#\\{([^\\}]+)\\}")
	end()

func start(p_source_node: Node, p_sequence: Resource, speaker: Node = null):
	clear()
	show()
	now = OS.get_datetime(true)
	source_node = p_source_node
	sequence = p_sequence
	if speaker:
		main_speaker = speaker
	else:
		main_speaker = source_node
	talked = Global.stat("talked"+main_speaker.get_path())
	set_process(true)
	set_process_input(true)
	Global.can_pause = false
	var first_index = INF
	# I forgot to specify a first item and I'm not going to bother lol
	for c in sequence.dialog.keys():
		if c < first_index:
			first_index = c
	current_item = sequence.get(first_index)
	advance()

func clear():
	is_exiting = false
	discussed = {}
	otherwise = false
	call_stack = []
	for c in messages.get_children():
		c.queue_free()
	clear_replies()

func clear_replies():
	for c in replies.get_children():
		c.queue_free()

func get_next():
	var c = sequence.canonical_next(current_item)
	if !c:
		exit()
	else:
		current_item = c
		advance()

func advance():
	otherwise = false
	if !current_item:
		exit()
		return
	clear_replies()
	var result := false
	while !result:
		if !current_item:
			exit()
			return
		# Conditions on replies are handles in list_replies()
		if current_item.type == DialogItem.Type.REPLY:
			result = true
			break
		var cond: Array = current_item.conditions
		result = true
		for c in cond:
			var r = check_condition(c)
			if r is Dictionary:
				if r == RESULT_END:
					return
				elif r == RESULT_PAUSE:
					pause()
					return
				elif r == RESULT_SKIP:
					advance()
					return
			elif !r:
				result = false
				break
		if !result:
			current_item = sequence.failed_next(current_item)
			if sequence.went_up:
				otherwise = false
		elif current_item.text == "":
			current_item = sequence.canonical_next(current_item)
			result = false
	
	match current_item.type:
		DialogItem.Type.MESSAGE:
			show_message()
		DialogItem.Type.REPLY:
			list_replies()
		DialogItem.Type.NARRATION:
			show_narration()

func list_replies():
	var reply: DialogItem = current_item
	while reply and reply.type == DialogItem.Type.REPLY:
		skip_reply = false
		var cond = reply.conditions
		var result := true
		for c in cond:
			if !check_condition(c):
				result = false
				break
		if result:
			var b := Button.new()
			b.text = reply.text
			replies.add_child(b)
			var r = reply
			var s = skip_reply
			var _x = b.connect("pressed", self, "choose_reply", [r, s])
		reply = sequence.next(reply)
	if replies.get_child_count() == 0:
		print("\tNo replies.")
		current_item = reply
		advance()
	$reply_timer.start()

func _on_reply_timer_timeout():
	replies.get_child(0).grab_focus()

func choose_reply(item: DialogItem, skip: bool):
	if !skip:
		insert_label("You: %s" % item.text, player_font, player_color)
		last_speaker = "You"
	current_item = item
	get_next()

func show_message():
	var speaker: String = current_item.speaker	
	if speaker == "":
		if "visual_name" in main_speaker:
			speaker = main_speaker.visual_name
		else:
			speaker = main_speaker.name.capitalize()

	var text := ""
	if speaker != last_speaker:
		text = "%s: %s" % [speaker, current_item.text]
	else:
		text = current_item.text
	last_speaker = speaker
	
	if speaker == "You":
		insert_label(text, player_font, player_color)
	else:
		insert_label(text, speaker_font, speaker_color)

func show_narration():
	insert_label(current_item.text, narration_font, narration_color)

func insert_label(text: String, font: Font, color: Color):
	var label := Label.new()
	label.autowrap = true
	label.text = interpolate(text)
	label.add_font_override("font", font)
	label.add_color_override("font_color", color)
	messages.add_child(label)

func interpolate(line: String):
	var matches := r_interpolate.search_all(line)
	var text := line
	for m in matches:
		var ex = evaluate(m.get_string(1))
		text = text.replace(m.get_string(), str(ex))
	return text

func evaluate(ex_text: String):
	var expr: Expression = Expression.new()
	var err = expr.parse(ex_text, ["Global"])
	if err != OK:
		print_debug("\tFailed to parse {%s}. Code %d" % [ex_text, err])
		return true
	
	var r = expr.execute([Global], self)
	
	if expr.has_execute_failed():
		print_debug("\tFailed to execute {%s}.\n\t%s" 
			% [ex_text, expr.get_error_text()])
		return true
	return r

func check_condition(cond: String):
	var oif: RegExMatch = r_otherwise_if.search(cond)
	if oif:
		if !otherwise:
			return false
		cond = cond.replace(oif.get_string(), "")
	
	var result = evaluate(cond)
	otherwise = !result
	return result

#TODO: Implement
func track_conversation_time():
	return true

#TODO: Implement
func seconds_from_last_conversation() -> int:
	return 10

# TODO
func format(_style: String):
	return true

# TODO
func animation(_animation: String, _node: String = ""):
	return true

func event(tag: String, should_pause := true):
	if should_pause:
		pause()
	emit_signal("event", tag)
	emit_signal("event_with_source", tag, main_speaker)
	if main_speaker.has_method(tag):
		main_speaker.call(tag)
	return true

func goto(label: String):
	current_item = sequence.get(label)
	return RESULT_SKIP

func skip():
	skip_reply = true
	# Ironic how skip() does not return RESULT_SKIP
	return true

func exit():
	var _x = Global.add_stat("talked"+main_speaker.get_path())
	emit_signal("exited")
	return RESULT_END

func mention(topic):
	discussed[topic] = true
	return true

func mentioned(topic):
	return topic in discussed

func subtopic(label):
	call_stack.push_back(current_item)
	return goto(label)

func back():
	# If there's nothing on the call stack, we just continue
	if call_stack.empty():
		return true
	var caller = call_stack.pop_back()
	current_item = caller
	get_next()
	return RESULT_SKIP

func exiting():
	is_exiting = true
	return true

func end():
	hide()
	set_process(false)
	set_process_input(false)
	Global.can_pause = true

func fast_exit():
	if is_exiting:
		get_next()
	else:
		is_exiting = true
		current_item = sequence.get("_exit")
		advance()

func pause():
	hide()
	set_process_input(false)
	set_process(false)

func resume():
	show()
	set_process_input(true)
	set_process(true)
