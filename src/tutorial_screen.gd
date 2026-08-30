class_name TutorialScreen
extends Control

const _TITLE_SCENE_PATH := "res://scenes/title_screen.tscn"
const _ACCEPT_ACTION := &"ui_accept"
const _CANCEL_ACTION := &"ui_cancel"

var _is_leaving: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if _is_leaving or (
		not event.is_action_pressed(_ACCEPT_ACTION)
		and not event.is_action_pressed(_CANCEL_ACTION)
	):
		return

	_is_leaving = true
	get_viewport().set_input_as_handled()
	get_tree().change_scene_to_file(_TITLE_SCENE_PATH)
