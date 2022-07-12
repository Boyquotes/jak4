extends Control

signal exited
signal event(id)
signal event_with_source(id, source)

var shopping := false setget set_shopping

onready var player: PlayerBody = get_parent().get_parent()
var main_speaker: Node
var source_node: Node
var last_speaker: String

var current_item : DialogItem
var sequence: Resource

export(Font) var speaker_font
export(Font) var narration_font
export(Font) var player_font

export(Color) var narration_color := Color.dimgray
export(Color) var player_color := Color.deeppink

onready var replies := $messages/replies
onready var messages := $messages/messages/list

const RESULT_SKIP := {"result":"skip"}
const RESULT_PAUSE := {"result":"pause"}
const RESULT_END := {"result":"end"}
const RESULT_NOSKIP := {"result":"noskip"}

var r_otherwise_if := RegEx.new()
var r_interpolate := RegEx.new()

var otherwise := false
var talked := 0
var skip_reply := false
var discussed := {}
var is_exiting := false
# Stack of IDs for DialogItems
var call_stack:= []
var advance_on_resume := false

const SECONDS_PER_YEAR := 356*24*3600
const SECONDS_PER_MONTH := 30*24*3600
const SECONDS_PER_DAY := 24*3600
const SECONDS_PER_HOUR := 3600
const SECONDS_PER_MINUTE := 60

func _input(event):
	if shopping:
		if event.is_action_pressed("ui_cancel"):
			set_shopping(false)
			resume()
	elif event.is_action_pressed("ui_cancel"):
		fast_exit()
	elif event.is_action_pressed("dialog_coat"):
		trade_coats()
	elif current_item.type != DialogItem.Type.REPLY and event.is_action_pressed("ui_accept"):
		get_next()

func _process(_delta):
	var scr = $messages/messages
	scr.scroll_vertical = scr.get_v_scrollbar().max_value

func _ready():
	var _x = r_otherwise_if.compile("^\\s*otherwise\\s+if\\s+")
	_x = r_interpolate.compile("#\\{([^\\}]+)\\}")
	end()

func start(p_source_node: Node, p_sequence: Resource, speaker: Node = null, starting_label:= ""):
	set_shopping(false)
	clear()
	source_node = p_source_node
	sequence = p_sequence
	if speaker:
		main_speaker = speaker
	else:
		main_speaker = source_node
	talked = Global.stat(get_talked_stat())
	set_process(true)
	set_process_input(true)
	Global.can_pause = false
	var first_index = INF
	# I forgot to specify a first item and I'm not going to bother lol
	var s: DialogItem = sequence.get(starting_label)
	if !s:
		for c in sequence.dialog.keys():
			if c < first_index:
				first_index = c
		current_item = sequence.get(first_index)
	else:
		current_item = s
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
	var noskip := false
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
				elif r == RESULT_NOSKIP:
					noskip = true
			elif !r:
				result = false
				break
		if !result:
			current_item = sequence.failed_next(current_item)
			if sequence.went_up:
				otherwise = false
		elif current_item.text == "" and !noskip:
			current_item = sequence.canonical_next(current_item)
			result = false
	
	if current_item.text != "":
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
			b.clip_text = false
			var l := Label.new()
			replies.add_child(b)
			b.add_child(l)
			l.anchor_left = 0
			l.anchor_right = 1
			l.anchor_top = 0
			l.anchor_bottom = 1
			l.margin_left = 10
			l.margin_right = -10
			l.margin_top = 5
			l.margin_bottom = -5
			l.autowrap = true
			l.text = reply.text
			call_deferred("resize_replies")
			var r = reply
			var s = skip_reply
			var _x = b.connect("pressed", self, "choose_reply", [r, s])
		reply = sequence.next(reply)
	if replies.get_child_count() == 0:
		print("\tNo replies.")
		current_item = reply
		advance()
	$input_timer.start()

func resize_replies():
	for b in replies.get_children():
		if !(b is Button):
			continue
		var l: Label = b.get_child(0)
		b.rect_min_size.y = l.get_line_count()*l.get_line_height()*1.25 + l.margin_top + l.margin_bottom

func _on_input_timer_timeout():
	if shopping:
		if $shop.items_window.get_child_count() >= 3:
			$shop.items_window.get_child(2).grab_focus()
	else:
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
		insert_label(text, speaker_font)

func show_narration():
	insert_label(current_item.text, narration_font, narration_color)

func insert_label(text: String, font: Font, color := Color.black):
	var label := Label.new()
	label.autowrap = true
	label.text = interpolate(text)
	if color != Color.black:
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

func end():
	hide()
	set_process(false)
	set_process_input(false)
	Global.can_pause = true

func trade_coats():
	if mentioned("_coat"):
		get_next()
		return
	var coat_item: DialogItem = sequence.get("_coat")
	if coat_item:
		mention("_coat")
		current_item = coat_item
		advance()
	else:
		insert_label("[You cannot trade coats with this person]", narration_font, narration_color)

func fast_exit():
	if is_exiting:
		get_next()
	else:
		is_exiting = true
		current_item = sequence.get("_exit")
		advance()

func pause():
	print("Pausing dialog...")
	hide()
	set_process_input(false)
	set_process(false)

func resume():
	show()
	set_process_input(true)
	set_process(true)
	if advance_on_resume:
		get_next()

func get_talked_stat():
	return "talked" + speaker_stat()

func ui_settings_apply():
	if player_font is DynamicFont:
		player_font.size = get_theme_default_font().size
	if narration_font is DynamicFont:
		narration_font.size = get_theme_default_font().size

func set_shopping(s):
	shopping = s
	$messages.visible = !shopping
	$shop.visible = shopping
	if shopping:
		$input_timer.start()

## Dialog functions

func exiting():
	is_exiting = true
	return true

func track_conversation_time():
	Global.set_stat("talk_time"+main_speaker.get_path(), OS.get_unix_time())

func seconds_since_conversation() -> int:
	var prev: int = Global.stat("talk_time"+main_speaker.get_path())
	var now: int = OS.get_unix_time()
	return now - prev

# TODO
func format(_style: String):
	return true

# TODO
func animation(_animation: String, _node: String = ""):
	return true

func event(tag: String, should_pause := false, auto_advance_on_resume:= true):
	emit_signal("event", tag)
	emit_signal("event_with_source", tag, main_speaker)
	if main_speaker.has_method(tag):
		main_speaker.call(tag)
	if should_pause:
		advance_on_resume = auto_advance_on_resume
		return RESULT_PAUSE
	else:
		return true

func goto(label: String):
	current_item = sequence.get(label)
	return RESULT_SKIP

func skip():
	skip_reply = true
	# Ironic how skip() does not return RESULT_SKIP
	return true

func noskip():
	return RESULT_NOSKIP

func exit():
	var stat: String = get_talked_stat()
	var _x = Global.add_stat(stat)
	emit_signal("exited")
	set_process_input(false)
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

func coat_trade_stat() -> String:
	return "coat_trade" + speaker_stat()

func traded_coats():
	return Global.stat(coat_trade_stat())

func swap_coats():
	var _x = Global.add_stat(coat_trade_stat())
	_x = Global.add_stat("trade_coat")
	var player_coat: Coat = player.current_coat
	var speaker_coat: Coat = main_speaker.get_coat()
	main_speaker.set_coat(player_coat)
	Global.add_coat(speaker_coat)
	player.set_current_coat(speaker_coat, true)
	Global.remove_coat(player_coat)
	return true

func speaker_stat() -> String:
	if !main_speaker:
		return ""
	if "friendly_id" in main_speaker and main_speaker.friendly_id != "":
		return main_speaker.friendly_id
	else:
		return str(main_speaker.get_path())

func can_discuss(stat: String) -> bool:
	return Global.stat(stat) and !Global.stat("discussed" + speaker_stat() + "/" + stat)

func mark_discussed(stat: String) -> bool:
	var _x = Global.add_stat("discussed" + speaker_stat() + "/" + stat)
	return true

func shop():
	set_shopping(true)
	$shop.start_shopping(main_speaker)
