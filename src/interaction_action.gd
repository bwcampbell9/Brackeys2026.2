## Base type for interaction behaviors attached beneath an [InteractionTarget].
## GDScript has no abstract methods, so [method is_available] must be
## overridden by every subclass; calling the base implementation is a
## programming error and fails loudly (via [method @GlobalScope.push_error])
## instead of silently reporting the action as available.
class_name InteractionAction
extends Node

## Canonical trigger enum (Tap = 0, Hold = 1) for interaction bindings and
## actions. GDScript treats identically-shaped enums declared in different
## scripts as distinct static types, so other scripts (e.g. an
## InteractionInputBinding resource) that need a Trigger value of their own
## should assign/compare it as a plain int rather than re-declaring or
## cross-assigning this enum, to stay compatible regardless of how their own
## exported property ends up typed.
enum InteractionInputTrigger { TAP, HOLD }

enum RunState { RUNNING, COMPLETED, FAILED }

@export var ActionId: StringName = &""
@export var Trigger: InteractionInputTrigger = InteractionInputTrigger.TAP


func is_available(_context: InteractionContext) -> bool:
	push_error(
		"%s must override is_available(); the base InteractionAction is abstract." % get_script().resource_path
	)
	return false


func execute(_context: InteractionContext) -> bool:
	return false


func begin(_context: InteractionContext) -> bool:
	return false


func update_interaction(_context: InteractionContext, _delta: float) -> RunState:
	return RunState.COMPLETED


func cancel(_context: InteractionContext) -> void:
	pass


func complete(context: InteractionContext) -> void:
	cancel(context)


func get_interaction_target() -> InteractionTarget:
	var parent := get_parent()
	if not (parent is InteractionTarget):
		push_error("InteractionAction's parent must be an InteractionTarget.")
		return null
	return parent
