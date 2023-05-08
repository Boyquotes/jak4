extends Object
class_name ChunkLoader

signal load_start
signal load_complete

enum Status {
	Unloaded,
	Loaded,
	Loading
}

var _nodes : Dictionary
var _status : Dictionary

var _lowres : Dictionary
var _hires : Dictionary

const PATH_CONTENT := "res://areas/chunks/%s.tscn"
const PATH_LOWRES := "res://areas/chunks/%s_lowres.tscn"

func _init():
	_status = {}
	_lowres = {}
	_hires = {}

func start_loading(chunks: Array):
	for c in chunks:
		_nodes[c.name] = c
		_status[c.name] = Status.Unloaded
	_load_lowres(chunks)

func _load_lowres(chunks: Array):
	call_deferred("_start_loading")
	var first_loaded = false
	for chunk in chunks:
		var name:String = chunk.name
		var hires_file :String = PATH_CONTENT % name
		if ResourceLoader.exists(hires_file):
			_hires[name] = hires_file
		var lowres_file: String = PATH_LOWRES % name
		if ResourceLoader.exists(lowres_file):
			var content = load(lowres_file)
			call_deferred("_add_lowres", name, content)
		if !first_loaded:
			first_loaded = true
	call_deferred("_complete_loading")

func _start_loading():
	emit_signal("load_start")

func _complete_loading():
	emit_signal("load_complete")

func _set_loaded(dict: Dictionary, name: String, content):
	dict[name] = content

func quit():
	pass

func _add_lowres(chunk: String, content: PackedScene):
	var l = content.instance()
	l.name = "lowres"
	_set_loaded(_lowres, chunk, l)
	if !is_loaded(_nodes[chunk]):
		_nodes[chunk].add_child(l)

func _add_content(chunk: String, content: PackedScene, active: bool):
	var c:Node = _nodes[chunk]
	if c.has_node("dynamic_content"):
		return
	else:
		if c.has_node("lowres"):
			var l = c.get_node("lowres")
			c.remove_child(l)
		var n = content.instance()
		n.name = "dynamic_content"
		n.set_active(active)
		c.add_child(n)

func is_alive():
	return false

func _get_content(dic:Dictionary, chunk: String):
	var res
	res = dic.get(chunk)
	if res is String:
		var data = load(res)
		dic[chunk] = data
		return data
	else:
		return res

func unload_all():
	for c in _nodes.values():
		queue_unload(c)

func queue_load(chunk: Spatial, active: bool):
	if _status[chunk.name] != Status.Unloaded:
		return
	_status[chunk.name] = Status.Loading
	if !(chunk.name in _hires):
		return
	if chunk.has_node("dynamic_content"):
		return

	if chunk.has_node("lowres"):
		chunk.remove_child(chunk.get_node("lowres"))
	var c = _get_content(_hires, chunk.name)

	if c is PackedScene:
		var n:Node = c.instance()
		n.name = "dynamic_content"
		n.set_active(active)
		chunk.add_child(n)
	_status[chunk.name] = Status.Loaded
	
func queue_unload(chunk: Spatial):
	if _status[chunk.name] != Status.Loaded:
		return
	_status[chunk.name] = Status.Unloaded
	if chunk.has_node("dynamic_content"):
		chunk.get_node("dynamic_content").queue_free()
	if chunk.name in _hires:
		var r = _hires[chunk.name]
		if r is Resource:
			_hires[chunk.name] = r.resource_path
	if !chunk.has_node("lowres"):
		var c = _get_content(_lowres, chunk.name)
		if c is Node:
			if !c.is_inside_tree():
				c.request_ready()
				chunk.add_child(c)
			else:
				c.name = "lowres"

func activate(chunk: Spatial):
	if chunk.has_node("dynamic_content"):
		chunk.get_node("dynamic_content").set_active(true)

func deactivate(chunk: Spatial):
	if chunk.has_node("dynamic_content"):
		chunk.get_node("dynamic_content").set_active(false)

func is_loaded(chunk: Spatial):
	return chunk and _status[chunk.name] == Status.Loaded
