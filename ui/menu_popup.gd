class_name MenuPopup
extends CanvasLayer


func _ready() -> void:
	visible = false


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
	_on_closed()


func _on_opened() -> void:
	pass


func _on_closed() -> void:
	pass
