extends Node

signal item_added(item_id: String)
signal item_removed(item_id: String)
signal inventory_changed()

const MAX_SLOTS := 8

var items: Array[String] = []
var selected_item: String = ""

func add_item(item_id: String) -> bool:
	if items.size() >= MAX_SLOTS:
		return false
	if items.has(item_id):
		return false
	items.append(item_id)
	item_added.emit(item_id)
	inventory_changed.emit()
	return true

func remove_item(item_id: String) -> void:
	items.erase(item_id)
	if selected_item == item_id:
		selected_item = ""
	item_removed.emit(item_id)
	inventory_changed.emit()

func has_item(item_id: String) -> bool:
	return items.has(item_id)

func select_item(item_id: String) -> void:
	if items.has(item_id):
		selected_item = item_id

func clear_selection() -> void:
	selected_item = ""
