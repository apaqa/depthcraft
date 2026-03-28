extends Node

var _tracked_nodes: Array[Node] = []


static func attach(root: Node) -> void:
	if root == null:
		return
	if root.get_node_or_null("UiAudioClickHook") != null:
		return
	var hook: Node = new()
	hook.name = "UiAudioClickHook"
	root.add_child(hook)
	hook.call("_bind_root", root)


func _bind_root(root: Node) -> void:
	_track_node(root)


func _track_node(node: Node) -> void:
	if node == null:
		return
	if not _tracked_nodes.has(node):
		_tracked_nodes.append(node)
	if not node.child_entered_tree.is_connected(_on_child_entered_tree):
		node.child_entered_tree.connect(_on_child_entered_tree)
	if node is Button:
		var button: Button = node as Button
		if button != null and not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed)
	for child: Node in node.get_children():
		_track_node(child)


func _exit_tree() -> void:
	for node: Node in _tracked_nodes:
		if not is_instance_valid(node):
			continue
		if node.child_entered_tree.is_connected(_on_child_entered_tree):
			node.child_entered_tree.disconnect(_on_child_entered_tree)
		if node is Button:
			var button: Button = node as Button
			if button != null and button.pressed.is_connected(_on_button_pressed):
				button.pressed.disconnect(_on_button_pressed)
	_tracked_nodes.clear()


func _on_child_entered_tree(child: Node) -> void:
	_track_node(child)


func _on_button_pressed() -> void:
	AudioManager.play_sfx("ui_click")
