class_name CustomerVisualController
extends Node

const _IDLE_ANIMATION := &"idle"
const _WALK_ANIMATION := &"walk"
const _EATING_ANIMATION := &"eating"

@export var SpritePath: NodePath = NodePath("../AnimatedSprite2D")

@export var MotorPath: NodePath = NodePath("../NpcMotor")

@export var TaskPublisherPath: NodePath = NodePath("../WorkstationTaskPublisher")

@export var EatingAudioPath: NodePath = NodePath("../EatingAudio")

@export var EatingSounds: Array[AudioStream] = []

@export var HmmAudioPath: NodePath = NodePath("../HmmAudio")

@export var HmmSounds: Array[AudioStream] = []

@export_range(1.0, 60.0, 1.0, "or_greater") var InitialMinimumHmmDelaySeconds: float = 5.0

@export_range(1.0, 60.0, 1.0, "or_greater") var InitialMaximumHmmDelaySeconds: float = 15.0

@export_range(1.0, 300.0, 1.0, "or_greater") var MinimumHmmDelaySeconds: float = 5.0

@export_range(1.0, 300.0, 1.0, "or_greater") var MaximumHmmDelaySeconds: float = 15.0

var _sprite: AnimatedSprite2D
var _actor: CharacterBody2D
var _motor  # NpcMotor (duck-typed; ported under the NPC systems slice)
var _task_publisher: WorkstationTaskPublisher
var _eating_audio: AudioStreamPlayer2D
var _hmm_audio: AudioStreamPlayer2D
var _random: RandomNumberGenerator
var _current_animation: StringName = &""
var _hmm_delay_remaining: float = 0.0


func _ready() -> void:
	_actor = get_parent() as CharacterBody2D
	if _actor == null:
		push_error("CustomerVisualController must be a child of CharacterBody2D.")
		return
	_sprite = get_node_or_null(SpritePath)
	if _sprite == null:
		push_error("CustomerVisualController requires an AnimatedSprite2D.")
		return
	_motor = get_node_or_null(MotorPath)
	if _motor == null:
		push_error("CustomerVisualController requires an NpcMotor.")
		return
	_task_publisher = get_node_or_null(TaskPublisherPath)
	if _task_publisher == null:
		push_error("CustomerVisualController requires a WorkstationTaskPublisher.")
		return
	_eating_audio = get_node_or_null(EatingAudioPath)
	if _eating_audio == null:
		push_error("CustomerVisualController requires an eating audio player.")
		return
	_hmm_audio = get_node_or_null(HmmAudioPath)
	if _hmm_audio == null:
		push_error("CustomerVisualController requires a hmm audio player.")
		return
	_random = RandomNumberGenerator.new()
	_random.randomize()
	_schedule_next_hmm_with_range(
		InitialMinimumHmmDelaySeconds, InitialMaximumHmmDelaySeconds
	)
	_set_animation(_IDLE_ANIMATION)


func _process(delta: float) -> void:
	_sprite.global_rotation = 0.0
	if not is_zero_approx(_actor.velocity.x):
		_sprite.flip_h = _actor.velocity.x > 0.0
	_update_hmm_audio(delta)
	_set_animation(
		_EATING_ANIMATION
		if _task_publisher.is_consuming
		else (_IDLE_ANIMATION if _motor.is_at_target else _WALK_ANIMATION)
	)


func _set_animation(animation: StringName) -> void:
	if _current_animation == animation:
		return

	_current_animation = animation
	_sprite.play(animation)
	if animation == _EATING_ANIMATION and EatingSounds.size() > 0:
		_eating_audio.stream = EatingSounds[_random.randi_range(0, EatingSounds.size() - 1)]
		_eating_audio.play()


func _update_hmm_audio(delta: float) -> void:
	_hmm_delay_remaining -= delta
	if _hmm_delay_remaining > 0.0 or _hmm_audio.playing or HmmSounds.size() == 0:
		return

	_hmm_audio.stream = HmmSounds[_random.randi_range(0, HmmSounds.size() - 1)]
	_hmm_audio.play()
	_schedule_next_hmm()


func _schedule_next_hmm() -> void:
	_schedule_next_hmm_with_range(MinimumHmmDelaySeconds, MaximumHmmDelaySeconds)


func _schedule_next_hmm_with_range(
	minimum_delay_seconds: float, maximum_delay_seconds: float
) -> void:
	_hmm_delay_remaining = _random.randf_range(
		minimum_delay_seconds, maxf(minimum_delay_seconds, maximum_delay_seconds)
	)
