@tool
class_name InteractionInputBinding
extends Resource
## Maps an input action to the ordered set of interaction action ids it triggers.

enum InteractionInputTrigger {
	TAP,
	HOLD,
}

@export var InputAction: StringName = &"interact"
@export var Trigger: InteractionInputTrigger = InteractionInputTrigger.TAP
@export var ActionIds: Array[StringName] = []
