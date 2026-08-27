extends Node


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_enable_translation_for_tree")


func _on_node_added(node: Node) -> void:
	if node is Control:
		node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS


func _enable_translation_for_tree() -> void:
	_enable_translation(get_tree().root)


func _enable_translation(node: Node) -> void:
	if node is Control:
		node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	for child in node.get_children():
		_enable_translation(child)