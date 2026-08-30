class_name MenuPopup
extends CanvasLayer

signal closed


func _ready() -> void:
	visible = false


# InventoryManager.is_open is shared state on an autoload, so a menu that goes away while it is
# still up - a scene change while a dialogue is open, a level reload - would leave every input
# getter gated for good: the next scene starts with the player unable to move, and no menu left on
# screen to close and clear it.
func _exit_tree() -> void:
	if visible:
		visible = false
		InventoryManager.is_open = false


func _process(_delta) -> void:
	if visible and Input.is_action_just_pressed("ui_cancel"):
		close()


# Guards against stacking on top of another open menu (e.g. the inventory screen), since
# InventoryManager.is_open is the single shared flag every menu uses to freeze player input.
func open() -> void:
	if InventoryManager.is_open:
		return
	visible = true
	InventoryManager.is_open = true
	_on_opened()


func close() -> void:
	visible = false
	InventoryManager.is_open = false
	closed.emit()
	_on_closed()


func _on_opened() -> void:
	pass


func _on_closed() -> void:
	pass
