extends GutTest

const ItemSlotScene = preload("res://ui/inventory/ItemSlot.tscn")

var slot : ItemSlot


func before_each():
	slot = ItemSlotScene.instantiate()
	add_child_autofree(slot)
	await wait_physics_frames(1)


func test_pressing_the_button_emits_selected_with_the_slots_item():
	var item := ItemData.new()
	slot.set_slot_data(item, 1)

	watch_signals(slot)
	slot.button.pressed.emit()

	assert_signal_emitted_with_parameters(slot, "selected", [item])


func test_pressing_an_empty_slot_emits_selected_with_null():
	slot.set_slot_data(null, 0)

	watch_signals(slot)
	slot.button.pressed.emit()

	assert_signal_emitted_with_parameters(slot, "selected", [null])


func test_empty_slot_shows_no_icon():
	var item := ItemData.new()
	item.icon = PlaceholderTexture2D.new()
	slot.set_slot_data(item, 1)
	assert_not_null(slot.icon.texture, "sanity: a real item with an icon shows one")

	slot.set_slot_data(null, 0)
	assert_null(slot.icon.texture, "an empty slot should show no icon at all")


# Regression test: the slot's Button is fully transparent (self_modulate alpha 0, so its
# click-hitbox doesn't paint over the Icon sprite) which also hides its own theme focus outline -
# the slot's background color standing in for it was the actual fix, this proves it still toggles.
func test_focusing_the_button_highlights_the_slot_background():
	var rest_color : Color = slot.color

	slot.button.grab_focus()
	assert_ne(slot.color, rest_color, "focusing the slot should change its background color")

	slot.button.release_focus()
	assert_eq(slot.color, rest_color, "losing focus should restore the original background color")


# Navigating onto a slot with keyboard/gamepad should preview it immediately, same as pressing it,
# rather than requiring an extra confirm press just to see what it is.
func test_focusing_the_button_emits_selected_without_pressing():
	var item := ItemData.new()
	slot.set_slot_data(item, 1)

	watch_signals(slot)
	slot.button.grab_focus()

	assert_signal_emitted_with_parameters(slot, "selected", [item])
