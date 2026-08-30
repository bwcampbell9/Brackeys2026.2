class_name GameScoreController
extends CanvasLayer

const INSTANT_WIN_ACTION := &"debug_instant_win"
const WIN_AUDIO_PLAYER_NAME := "WinAudio"
const WIN_SOUND_PATH := "res://assets/sounds/win.wav"

## Mirrors WorkstationTaskPublisher.PublisherGroup; kept local so this file does not
## depend on that sibling script's exact constant name while ports run in parallel.
const PUBLISHER_GROUP := &"workstation_task_publishers"

## Mirrors WorkstationTaskPublisher.CustomerOrderOutcome (Correct=0, Wrong=1, Missed=2).
const OUTCOME_CORRECT := 0
const OUTCOME_WRONG := 1
const OUTCOME_MISSED := 2

@export var ScoreLabelPath: NodePath = NodePath("Score")
@export var ScoreUpAudioPath: NodePath = NodePath("ScoreUpAudio")
@export var ScoreDownAudioPath: NodePath = NodePath("ScoreDownAudio")
@export var CorrectOrderPoints: int = 5
@export var WrongOrderPenalty: int = 4
@export var MissedOrderPenalty: int = 8
@export_range(1, 10000, 1, "or_greater") var MaximumScore: int = 100
@export_range(1, 10000, 1, "or_greater") var StartingScore: int = 50

@export_group("Level Progression")
@export_file("*.tscn") var NextLevelScenePath: String = ""
@export var NextLevelRevealTargetPath: NodePath = NodePath("Player")
@export var RevealNextLevelAtViewportCenter: bool = false

@export_group("")
@export var GameOverControllerPath: NodePath = NodePath("../GameOverController")
@export_range(0.1, 2, 0.05, "or_greater") var MaximumScoreTweenDuration: float = 0.65
@export_range(0.05, 1, 0.05, "or_greater") var ScoreTweenSecondsPerPoint: float = 0.06
@export_range(0.05, 1, 0.05, "or_greater") var ScorePopupIntroDuration: float = 0.18
@export_range(0.1, 2, 0.05, "or_greater") var ScorePopupRiseDuration: float = 0.65
@export_range(0, 90, 1) var ScorePopupMaximumAngleDegrees: float = 12.0
@export_range(1, 200, 1, "or_greater") var ScorePopupVerticalOffset: float = 40.0
@export_range(0.5, 2, 0.01) var ScoreTickMinimumPitchScale: float = 0.8
@export_range(0.5, 2, 0.01) var ScoreTickMaximumPitchScale: float = 1.2

var _publishers: Array[WorkstationTaskPublisher] = []
var _score_label: Label
var _score_up_audio: AudioStreamPlayer
var _score_down_audio: AudioStreamPlayer
var _game_over_controller: GameOverController
var _random: RandomNumberGenerator
var _score_tween: Tween
var _displayed_score: float = 0.0
var _displayed_score_value: int = 0
var _score: int = 0
var _has_played_win_celebration: bool = false
var _is_completing_level: bool = false

var score: int:
	get:
		return _score


func get_score() -> int:
	return _score


func _ready() -> void:
	_score_label = get_node_or_null(ScoreLabelPath) as Label
	if _score_label == null:
		push_error("GameScoreController requires a score label.")
		return

	_score_up_audio = get_node_or_null(ScoreUpAudioPath) as AudioStreamPlayer
	if _score_up_audio == null:
		push_error("GameScoreController requires a score-up audio player.")
		return

	_score_down_audio = get_node_or_null(ScoreDownAudioPath) as AudioStreamPlayer
	if _score_down_audio == null:
		push_error("GameScoreController requires a score-down audio player.")
		return

	_game_over_controller = get_node_or_null(GameOverControllerPath) as GameOverController
	if _game_over_controller == null:
		push_error("GameScoreController requires a game-over controller.")
		return

	MaximumScore = maxi(1, MaximumScore)
	_score = clampi(StartingScore, 0, MaximumScore)
	_displayed_score = float(_score)
	_displayed_score_value = _score
	_random = RandomNumberGenerator.new()
	_random.randomize()
	_update_score_label(_score)
	call_deferred("_connect_publishers")


func _exit_tree() -> void:
	for publisher in _publishers:
		if (
			is_instance_valid(publisher)
			and publisher.customer_order_resolved.is_connected(apply_customer_order_outcome)
		):
			publisher.customer_order_resolved.disconnect(apply_customer_order_outcome)
	_publishers.clear()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed(INSTANT_WIN_ACTION)
		and not (event is InputEventKey and event.echo)
	):
		_complete_level_for_testing()
		get_viewport().set_input_as_handled()


func _connect_publishers() -> void:
	for node in get_tree().get_nodes_in_group(PUBLISHER_GROUP):
		if not (node is WorkstationTaskPublisher) or not node.ConsumeDeliveredItem:
			continue

		node.customer_order_resolved.connect(apply_customer_order_outcome)
		_publishers.append(node)


func apply_customer_order_outcome(outcome: int) -> void:
	var score_delta: int
	match outcome:
		OUTCOME_CORRECT:
			score_delta = CorrectOrderPoints
		OUTCOME_WRONG:
			score_delta = -WrongOrderPenalty
		OUTCOME_MISSED:
			score_delta = -MissedOrderPenalty
		_:
			push_error("Unknown customer order outcome: %s" % outcome)
			return

	var previous_score := _score
	_score = clampi(previous_score + score_delta, 0, MaximumScore)
	var applied_delta := _score - previous_score
	if applied_delta != 0:
		_show_score_change(applied_delta)
		_animate_displayed_score()

	if _score == 0:
		_game_over_controller.trigger_game_over()
	elif previous_score < MaximumScore and _score == MaximumScore:
		_begin_level_completion()


func _complete_level_for_testing() -> void:
	if _is_completing_level:
		return

	if _score_tween != null:
		_score_tween.kill()
	_score_tween = null
	_score = MaximumScore
	_displayed_score = float(_score)
	_displayed_score_value = _score
	_update_score_label(_score)
	_begin_level_completion()


func _begin_level_completion() -> void:
	if _is_completing_level:
		return

	_is_completing_level = true
	if not _has_played_win_celebration:
		_has_played_win_celebration = true
		_play_win_sound()
		_show_win_confetti(_score_label.get_global_rect().get_center())

	if NextLevelScenePath.strip_edges().is_empty():
		return

	var transition := CircleTransition.new()
	get_tree().root.add_child(transition)
	var result: Error = await transition.transition_to_scene(
		NextLevelScenePath,
		NextLevelRevealTargetPath,
		_score_label.get_global_rect().get_center(),
		RevealNextLevelAtViewportCenter
	)
	if result != OK and is_instance_valid(self):
		_is_completing_level = false


func _play_win_sound() -> void:
	if not ResourceLoader.exists(WIN_SOUND_PATH, "AudioStream"):
		push_warning("Win sound not found at '%s'." % WIN_SOUND_PATH)
		return

	var stream: AudioStream = load(WIN_SOUND_PATH)
	if stream == null:
		push_error("Could not load win sound at '%s'." % WIN_SOUND_PATH)
		return

	var audio_player := AudioStreamPlayer.new()
	audio_player.name = WIN_AUDIO_PLAYER_NAME
	audio_player.stream = stream
	audio_player.finished.connect(audio_player.queue_free)
	get_tree().root.add_child(audio_player)
	audio_player.play()


func _show_win_confetti(origin: Vector2) -> void:
	var confetti := WinConfetti.new()
	confetti.name = "WinConfetti"
	get_tree().root.add_child(confetti)
	confetti.burst(origin)


func _animate_displayed_score() -> void:
	if _score_tween != null:
		_score_tween.kill()

	var distance := absf(_score - _displayed_score)
	var duration := clampf(
		distance * maxf(0.01, ScoreTweenSecondsPerPoint),
		0.1,
		maxf(0.1, MaximumScoreTweenDuration)
	)
	_score_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale()
	_score_tween.tween_method(
		_set_displayed_score,
		_displayed_score,
		float(_score),
		duration
	).set_trans(Tween.TRANS_LINEAR)
	_score_tween.chain().tween_callback(func() -> void: _score_tween = null)


func _set_displayed_score(value: float) -> void:
	_displayed_score = value
	var displayed_score := roundi(value)
	if displayed_score == _displayed_score_value:
		return

	var increased := displayed_score > _displayed_score_value
	_displayed_score_value = displayed_score
	_update_score_label(displayed_score)
	_play_score_tick(_score_up_audio if increased else _score_down_audio)


func _play_score_tick(audio_player: AudioStreamPlayer) -> void:
	var minimum_pitch := maxf(0.01, ScoreTickMinimumPitchScale)
	var maximum_pitch := maxf(minimum_pitch, ScoreTickMaximumPitchScale)
	audio_player.pitch_scale = _random.randf_range(minimum_pitch, maximum_pitch)
	audio_player.play()


func _show_score_change(score_delta: int) -> void:
	var popup := Label.new()
	popup.name = "ScoreChange"
	popup.text = ("+%d" % score_delta) if score_delta > 0 else str(score_delta)
	popup.position = _score_label.position + Vector2(0.0, maxf(1.0, ScorePopupVerticalOffset))
	popup.size = _score_label.size
	popup.horizontal_alignment = _score_label.horizontal_alignment
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.self_modulate = Color.LIME_GREEN if score_delta > 0 else Color.RED
	popup.rotation = deg_to_rad(
		_random.randf_range(
			-maxf(0.0, ScorePopupMaximumAngleDegrees),
			maxf(0.0, ScorePopupMaximumAngleDegrees)
		)
	)
	popup.scale = Vector2.ONE * 0.65
	popup.modulate = Color(1.0, 1.0, 1.0, 0.0)
	popup.pivot_offset = popup.size * 0.5
	popup.add_theme_font_override("font", _score_label.get_theme_font("font"))
	popup.add_theme_font_size_override(
		"font_size",
		_score_label.get_theme_font_size("font_size") * 2
	)
	popup.add_theme_color_override("font_color", _score_label.get_theme_color("font_color"))
	popup.add_theme_color_override(
		"font_outline_color",
		_score_label.get_theme_color("font_outline_color")
	)
	popup.add_theme_constant_override(
		"outline_size",
		_score_label.get_theme_constant("outline_size")
	)
	add_child(popup)

	var intro_duration := maxf(0.05, ScorePopupIntroDuration)
	var rise_duration := maxf(0.1, ScorePopupRiseDuration)
	var popup_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale()
	popup_tween.tween_property(
		popup, "scale", Vector2.ONE, intro_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	popup_tween.parallel().tween_property(popup, "modulate:a", 1.0, intro_duration)
	popup_tween.tween_property(
		popup, "position", _score_label.position, rise_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	popup_tween.parallel().tween_property(popup, "rotation", 0.0, rise_duration)
	popup_tween.parallel().tween_property(popup, "scale", Vector2.ONE * 0.8, rise_duration)
	popup_tween.parallel().tween_property(popup, "modulate:a", 0.0, rise_duration)
	popup_tween.tween_callback(popup.queue_free)


func _update_score_label(displayed_score: int) -> void:
	_score_label.text = "Score: %d / %d" % [displayed_score, MaximumScore]
