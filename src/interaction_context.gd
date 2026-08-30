## Immutable bundle describing who is interacting, what they are holding, and
## which node owns the world-space item they are acting on. All members are
## read-only after construction, mirroring the original C# readonly struct.
class_name InteractionContext
extends RefCounted

var _actor: Node2D
var _carrier: PickupCarrier
var _world_item_root: Node

var actor: Node2D:
	get:
		return _actor

var carrier: PickupCarrier:
	get:
		return _carrier

var world_item_root: Node:
	get:
		return _world_item_root


## When [param world_item_root] is omitted, it defaults to the actor's parent.
## An actor without a parent has no world item root, which is an explicit
## setup failure rather than a silently accepted null.
func _init(p_actor: Node2D, p_carrier: PickupCarrier, p_world_item_root: Node = null) -> void:
	_actor = p_actor
	_carrier = p_carrier
	if p_world_item_root != null:
		_world_item_root = p_world_item_root
		return

	var parent := p_actor.get_parent() if p_actor != null else null
	if parent == null:
		push_error("An interaction actor must belong to a world item root.")
	_world_item_root = parent
