## Area2D anchor for the interaction actions attached beneath a world object.
## Actions are discovered by scanning direct children in scene order.
class_name InteractionTarget
extends Area2D

var target_owner: Node2D:
	get:
		var parent := get_parent()
		if not (parent is Node2D):
			push_error("InteractionTarget's owner must be a Node2D.")
			return null
		return parent


func find_action(action_id: StringName, trigger: int, context: InteractionContext) -> InteractionAction:
	for child in get_children():
		if (
			child is InteractionAction
			and child.ActionId == action_id
			and child.Trigger == trigger
			and child.is_available(context)
		):
			return child

	return null


func has_action(action_id: StringName, trigger: int) -> bool:
	for child in get_children():
		if child is InteractionAction and child.ActionId == action_id and child.Trigger == trigger:
			return true

	return false
