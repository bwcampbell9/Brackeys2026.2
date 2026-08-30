class_name KitchenTaskSystem
extends Node

var _broker: TaskBroker
## _catalog is left untyped: ItemSourceCatalog belongs to the items
## reservation and its configure/release members are not present on the
## native Node type.
var _catalog
var _kitchen_root: Node


func _ready() -> void:
	_broker = get_node("TaskBroker")
	_catalog = get_node("ItemSourceCatalog")

	var kitchen_root := get_parent()
	if kitchen_root == null:
		push_error("KitchenTaskSystem requires an owning kitchen root.")
		return
	_kitchen_root = kitchen_root

	_catalog.configure(_kitchen_root)
	call_deferred("_wire_participants")


func _wire_participants() -> void:
	var pending: Array[Node] = []
	for child in _kitchen_root.get_children():
		pending.push_back(child)

	while pending.size() > 0:
		var node: Node = pending.pop_back()
		if node is WorkstationTaskPublisher:
			(node as WorkstationTaskPublisher).configure(_broker)
		if node is NpcTaskRunner:
			(node as NpcTaskRunner).configure(_broker, _catalog)

		for child in node.get_children():
			pending.push_back(child)
