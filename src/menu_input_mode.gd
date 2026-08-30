@tool
class_name MenuInputMode
extends RefCounted
## Tracks whether the most recent menu input came from a controller or from
## keyboard/mouse, so menu UI can switch focus/cursor presentation accordingly.

## GDScript has no private-setter equivalent for static properties; callers are
## expected to treat this as read-only from outside this class, matching the
## observable `private set` contract from the C# source.
static var IsControllerActive: bool = false

static func deactivate_controller() -> void:
	IsControllerActive = false

## Observes an input event, updating IsControllerActive when the event is a
## recognized controller or keyboard/mouse input. Returns true when the event
## was recognized (and thus IsControllerActive may have changed).
static func observe(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var joypad_button := event as InputEventJoypadButton
		if joypad_button.pressed:
			IsControllerActive = true
			return true
	if event is InputEventJoypadMotion:
		var joypad_motion := event as InputEventJoypadMotion
		if absf(joypad_motion.axis_value) >= 0.5:
			IsControllerActive = true
			return true

	if event is InputEventMouseMotion or event is InputEventMouseButton:
		IsControllerActive = false
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			IsControllerActive = false
			return true

	return false

static func is_keyboard_input(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo
