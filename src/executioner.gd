class_name Executioner
extends Node2D

signal animation_finished

const _IDLE_ANIMATION := &"idle"
const _WALK_ANIMATION := &"walk"
const _TAKEOUT_ANIMATION := &"takeout"
const _CHOP_ANIMATION := &"chop"

var _sprite: AnimatedSprite2D
var _walk_audio: AudioStreamPlayer
var _chop_audio: AudioStreamPlayer
var _is_walking: bool = false


func _ready() -> void:
	_sprite = get_node("AnimatedSprite2D") as AnimatedSprite2D
	_walk_audio = get_node("WalkAudio") as AudioStreamPlayer
	_chop_audio = get_node("ChopAudio") as AudioStreamPlayer
	_sprite.animation_finished.connect(_on_animation_finished)
	_walk_audio.finished.connect(_on_walk_audio_finished)
	play_idle()


func play_idle() -> void:
	_is_walking = false
	_walk_audio.stop()
	_sprite.play(_IDLE_ANIMATION)


func play_walk() -> void:
	_is_walking = true
	_sprite.play(_WALK_ANIMATION)
	_walk_audio.play()


func play_takeout() -> void:
	_is_walking = false
	_walk_audio.stop()
	_sprite.play(_TAKEOUT_ANIMATION)


func play_chop() -> void:
	_is_walking = false
	_walk_audio.stop()
	_sprite.play(_CHOP_ANIMATION)
	_chop_audio.play()


func _on_animation_finished() -> void:
	animation_finished.emit()


func _on_walk_audio_finished() -> void:
	if _is_walking:
		_walk_audio.play()
