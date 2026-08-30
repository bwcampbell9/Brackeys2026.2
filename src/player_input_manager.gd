## Translates raw per-binding input actions into tap/hold interactions
## routed through [PlayerInteractor], tracking hold-time and press state per
## mapped input action.
class_name PlayerInputManager
extends Node

class InputState:
	var held_time: float = 0.0
	var hold_activated: bool = false
	var hold_threshold_reached: bool = false
	var press_observed: bool = false


const DEFAULT_INPUT_ACTION: StringName = &"interact"
const DEFAULT_SECONDARY_INTERACT_ACTION: StringName = &"secondary_interact"

var _input_states: Dictionary = {} # StringName -> InputState
var _actor: Node2D
var _interactor: PlayerInteractor
var _carrier: PickupCarrier
var _suppress_secondary_interact_until_released: bool = false
var _suppress_interaction_inputs_until_neutral: bool = false

@export_range(0.05, 2.0, 0.01, "or_greater") var HoldThreshold: float = 0.2

## Exported defaults must be constant expressions in GDScript, so this starts
## empty; [method _ensure_default_bindings] (called from [method _ready])
## populates it via [method _create_default_bindings] whenever it is empty,
## matching the original C# property-initializer-plus-_Ready() double
## default exactly.
@export var InteractionInputs: Array[InteractionInputBinding] = []
@export var SecondaryInteractAction: StringName = DEFAULT_SECONDARY_INTERACT_ACTION


func _ready() -> void:
	_actor = get_parent() as Node2D
	_interactor = _actor.get_node("Interactor") as PlayerInteractor
	_carrier = _actor.get_node("PickupCarrier") as PickupCarrier

	_ensure_default_bindings()
	for binding in InteractionInputs:
		if not binding.InputAction.is_empty() and not _input_states.has(binding.InputAction):
			_input_states[binding.InputAction] = InputState.new()


func _physics_process(delta: float) -> void:
	if _suppress_secondary_interact_until_released:
		if SecondaryInteractAction.is_empty() or not Input.is_action_pressed(SecondaryInteractAction):
			_suppress_secondary_interact_until_released = false
	elif (
		not SecondaryInteractAction.is_empty()
		and Input.is_action_just_pressed(SecondaryInteractAction)
		and _carrier.held_item != null
		and _carrier.held_item.try_secondary_interact()
	):
		return

	if _suppress_interaction_inputs_until_neutral:
		var has_active_interaction_input := false
		for input_action in _input_states.keys():
			has_active_interaction_input = (
				has_active_interaction_input
				or Input.is_action_pressed(input_action)
				or Input.is_action_just_pressed(input_action)
				or Input.is_action_just_released(input_action)
			)

		_suppress_interaction_inputs_until_neutral = has_active_interaction_input
		return

	for input_action in _input_states.keys():
		var state: InputState = _input_states[input_action]
		var just_pressed := Input.is_action_just_pressed(input_action)
		var just_released := Input.is_action_just_released(input_action)
		var was_hold_activated := state.hold_activated
		var was_hold_threshold_reached := state.hold_threshold_reached

		if just_pressed:
			if was_hold_activated:
				_interactor.cancel_active_interaction()

			state.held_time = 0.0
			state.hold_activated = false
			state.hold_threshold_reached = false
			state.press_observed = true

		if state.press_observed and Input.is_action_pressed(input_action):
			state.held_time += delta
			state.hold_threshold_reached = state.held_time >= HoldThreshold and _has_mapped_hold(input_action)
			if not state.hold_activated and state.hold_threshold_reached and _try_begin_mapped_hold(input_action):
				state.hold_activated = true

			if state.hold_activated and _interactor.has_active_interaction:
				_interactor.update_active_interaction(delta)

		if not just_released:
			continue

		if not state.press_observed:
			state.held_time = 0.0
			state.hold_activated = false
			state.hold_threshold_reached = false
			continue

		if was_hold_activated:
			if not just_pressed:
				_interactor.complete_active_interaction()
		elif not was_hold_threshold_reached and _has_mapped_tap(input_action) and not _try_execute_mapped_tap(input_action):
			_carrier.throw()

		if not just_pressed:
			state.held_time = 0.0
			state.hold_activated = false
			state.hold_threshold_reached = false
			state.press_observed = false


func suppress_current_gameplay_input() -> void:
	if _interactor.has_active_interaction:
		_interactor.cancel_active_interaction()

	_suppress_secondary_interact_until_released = true
	_suppress_interaction_inputs_until_neutral = true
	for state in _input_states.values():
		state.held_time = 0.0
		state.hold_activated = false
		state.hold_threshold_reached = false
		state.press_observed = false


func _try_execute_mapped_tap(input_action: StringName) -> bool:
	var context := InteractionContext.new(_actor, _carrier)
	for binding in InteractionInputs:
		if (
			binding.InputAction == input_action
			and binding.Trigger == InteractionAction.InteractionInputTrigger.TAP
			and _interactor.try_execute(binding.ActionIds, context)
		):
			return true

	return false


func _has_mapped_tap(input_action: StringName) -> bool:
	for binding in InteractionInputs:
		if binding.InputAction == input_action and binding.Trigger == InteractionAction.InteractionInputTrigger.TAP:
			return true

	return false


func _try_begin_mapped_hold(input_action: StringName) -> bool:
	var context := InteractionContext.new(_actor, _carrier)
	for binding in InteractionInputs:
		if (
			binding.InputAction == input_action
			and binding.Trigger == InteractionAction.InteractionInputTrigger.HOLD
			and _interactor.try_begin(binding.ActionIds, context)
		):
			return true

	return false


## Preserved from the original C# for exact behavioral parity even though it
## is not called from [method _physics_process] there either.
func _has_mapped_tap_target(input_action: StringName) -> bool:
	var context := InteractionContext.new(_actor, _carrier)
	for binding in InteractionInputs:
		if (
			binding.InputAction == input_action
			and binding.Trigger == InteractionAction.InteractionInputTrigger.TAP
			and _interactor.has_target_with_action(
				binding.ActionIds,
				InteractionAction.InteractionInputTrigger.TAP,
				context,
			)
		):
			return true

	return false


func _has_mapped_hold(input_action: StringName) -> bool:
	for binding in InteractionInputs:
		if binding.InputAction == input_action and binding.Trigger == InteractionAction.InteractionInputTrigger.HOLD:
			return true

	return false


func _ensure_default_bindings() -> void:
	if InteractionInputs.size() > 0:
		return

	InteractionInputs = _create_default_bindings()


## Trigger values are set via [method Object.set] with a plain int (0 = Tap,
## 1 = Hold) rather than an [InteractionAction.InteractionInputTrigger]
## reference: [InteractionInputBinding] declares its own separate
## [code]InteractionInputTrigger[/code] enum, and GDScript's static type
## checker treats identically-shaped enums declared in different scripts as
## distinct types, so a direct cross-script assignment would fail to
## compile. Routing the assignment through [method Object.set] keeps it a
## runtime Variant operation and sidesteps that restriction entirely.
static func _create_default_bindings() -> Array[InteractionInputBinding]:
	var tap_binding := InteractionInputBinding.new()
	tap_binding.InputAction = DEFAULT_INPUT_ACTION
	tap_binding.set(&"Trigger", 0) # InteractionAction.InteractionInputTrigger.TAP
	tap_binding.ActionIds.append(InteractionActionIds.Transfer)

	var hold_binding := InteractionInputBinding.new()
	hold_binding.InputAction = DEFAULT_INPUT_ACTION
	hold_binding.set(&"Trigger", 1) # InteractionAction.InteractionInputTrigger.HOLD
	hold_binding.ActionIds.append(InteractionActionIds.Process)

	var configure_binding := InteractionInputBinding.new()
	configure_binding.InputAction = &"configure_workstation"
	configure_binding.set(&"Trigger", 1) # InteractionAction.InteractionInputTrigger.HOLD
	configure_binding.ActionIds.append(InteractionActionIds.Configure)

	return [tap_binding, hold_binding, configure_binding] as Array[InteractionInputBinding]
