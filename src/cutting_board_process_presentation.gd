class_name CuttingBoardProcessPresentation
extends Node

const CHOP_PROGRESS_PARAMETER := &"chop_progress"

@export var ProcessActionPath: NodePath = NodePath("../InteractionTarget/ProcessItemAction")

@export var ProgressBarPath: NodePath = NodePath("../ProgressBar")

@export var ChoppingAudioPath: NodePath = NodePath("../ChoppingAudio")

@export var RaisedOffset: Vector2 = Vector2(-10.0, -28.0)

@export var StrikeOffset: Vector2 = Vector2(8.0, -6.0)

@export_range(0.05, 1.0, 0.01, "or_greater") var StrokeDuration: float = 0.12

var _process_action: TimedItemProcessAction
var _progress_bar: ProgressBar
var _chopping_audio: AudioStreamPlayer2D
var _board: Node2D
var _knife: PickupItem
var _processing_item: PickupItem
var _original_item_material: Material
var _chop_material: ShaderMaterial
var _uses_processing_animation := false
var _knife_tween: Tween


func _ready() -> void:
	_board = get_parent() as Node2D
	if _board == null:
		push_error("CuttingBoardProcessPresentation requires a Node2D parent.")
		return
	_process_action = get_node_or_null(ProcessActionPath) as TimedItemProcessAction
	if _process_action == null:
		push_error("CuttingBoardProcessPresentation requires a timed process action.")
		return
	_progress_bar = get_node_or_null(ProgressBarPath) as ProgressBar
	if _progress_bar == null:
		push_error("CuttingBoardProcessPresentation requires a progress bar.")
		return
	_chopping_audio = get_node_or_null(ChoppingAudioPath) as AudioStreamPlayer2D
	if _chopping_audio == null:
		push_error("CuttingBoardProcessPresentation requires a chopping audio player.")
		return

	_process_action.processing_started.connect(_on_processing_started)
	_process_action.progress_changed.connect(_on_progress_changed)
	_process_action.processing_canceled.connect(_on_processing_canceled)
	_process_action.processing_completed.connect(_on_processing_completed)
	_reset_presentation()


func _exit_tree() -> void:
	if is_instance_valid(_process_action):
		if _process_action.processing_started.is_connected(_on_processing_started):
			_process_action.processing_started.disconnect(_on_processing_started)
		if _process_action.progress_changed.is_connected(_on_progress_changed):
			_process_action.progress_changed.disconnect(_on_progress_changed)
		if _process_action.processing_canceled.is_connected(_on_processing_canceled):
			_process_action.processing_canceled.disconnect(_on_processing_canceled)
		if _process_action.processing_completed.is_connected(_on_processing_completed):
			_process_action.processing_completed.disconnect(_on_processing_completed)

	_reset_presentation()


func _on_processing_started() -> void:
	_knife = _process_action.active_tool
	_start_chop_preview()
	_progress_bar.value = 0.0
	_progress_bar.visible = true
	_start_knife_animation()
	_chopping_audio.play()


func _on_progress_changed(progress: float) -> void:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	_progress_bar.value = clamped_progress * 100.0
	if _chop_material != null:
		_chop_material.set_shader_parameter(CHOP_PROGRESS_PARAMETER, clamped_progress)


func _on_processing_canceled() -> void:
	_end_chop_preview(true)
	_reset_presentation()


func _on_processing_completed(item: PickupItem) -> void:
	_end_chop_preview(false)
	_reset_presentation()

	if item is BabyPickupItem:
		get_tree().call_group(
			GameOverController.GAME_OVER_GROUP,
			"trigger_game_over_at",
			item.global_position
		)


func _start_chop_preview() -> void:
	_processing_item = _process_action.active_item
	if _processing_item == null:
		push_error("Cutting presentation requires an active item when processing starts.")
		return
	var definition: PickupItemDefinition = _processing_item.Definition
	if definition == null:
		push_error("Cutting presentation requires the active item to have a definition.")
		return
	var recipe: ProcessingRecipe = _process_action.Recipe
	var transformation: ItemTransformation = recipe.Transformation if recipe != null else null
	if transformation == null:
		push_error("Cutting presentation requires a processing transformation.")
		return

	if definition.ProcessingSpriteFrames != null:
		_uses_processing_animation = true
		_processing_item.play_processing_animation(definition.ProcessingSpriteFrames)
		return

	var source_material: ShaderMaterial = transformation.FallbackMaterial as ShaderMaterial
	if source_material == null:
		source_material = transformation.resolve(definition).VisualMaterial as ShaderMaterial
	if source_material == null:
		push_error("Cutting presentation requires a shader material.")
		return

	_original_item_material = _processing_item.get_visual_material()
	_chop_material = source_material.duplicate() as ShaderMaterial
	if _chop_material == null:
		push_error("Cutting presentation could not duplicate the chop material.")
		return
	_chop_material.set_shader_parameter(CHOP_PROGRESS_PARAMETER, 0.0)
	_processing_item.set_visual_material(_chop_material)


func _end_chop_preview(restore_original_material: bool) -> void:
	if restore_original_material and is_instance_valid(_processing_item):
		if _uses_processing_animation:
			_processing_item.restore_definition_visual()
		else:
			_processing_item.set_visual_material(_original_item_material)

	_processing_item = null
	_original_item_material = null
	_chop_material = null
	_uses_processing_animation = false


func _start_knife_animation() -> void:
	if _knife == null:
		return

	var raised_position: Vector2 = _board.global_position + RaisedOffset
	var strike_position: Vector2 = _board.global_position + StrikeOffset
	_knife.global_position = raised_position
	_knife.global_rotation = -0.8

	_knife_tween = _knife.start_motion_tween().set_loops()
	_knife_tween.set_trans(Tween.TRANS_SINE)
	_knife_tween.set_ease(Tween.EASE_IN_OUT)
	_knife_tween.tween_property(_knife, NodePath("global_position"), strike_position, StrokeDuration)
	_knife_tween.parallel().tween_property(_knife, NodePath("global_rotation"), 0.25, StrokeDuration)
	_knife_tween.tween_property(_knife, NodePath("global_position"), raised_position, StrokeDuration)
	_knife_tween.parallel().tween_property(_knife, NodePath("global_rotation"), -0.8, StrokeDuration)


func _reset_presentation() -> void:
	_end_chop_preview(true)
	if is_instance_valid(_chopping_audio):
		_chopping_audio.stop()

	if is_instance_valid(_knife) and not _knife.is_available:
		_knife.reset_attachment_presentation()
	elif _knife_tween != null:
		_knife_tween.kill()

	_knife_tween = null
	_knife = null
	if is_instance_valid(_progress_bar):
		_progress_bar.value = 0.0
		_progress_bar.visible = false
