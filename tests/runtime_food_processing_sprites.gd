extends SceneTree

const POTATO_SCENE := preload("res://scenes/pickup_item.tscn")
const CARROT_SCENE := preload("res://scenes/carrot_item.tscn")
const CARROT_CONTAINER_SCENE := preload("res://scenes/carrot_container.tscn")
const POTATO_CONTAINER_SCENE := preload("res://scenes/potato_container.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	var hold_point := Node2D.new()
	var potato := POTATO_SCENE.instantiate() as RigidBody2D
	var carrot := CARROT_SCENE.instantiate() as RigidBody2D
	var carrot_container := CARROT_CONTAINER_SCENE.instantiate() as StaticBody2D
	var potato_container := POTATO_CONTAINER_SCENE.instantiate() as StaticBody2D
	world.add_child(hold_point)
	world.add_child(potato)
	world.add_child(carrot)
	world.add_child(carrot_container)
	world.add_child(potato_container)
	root.add_child(world)
	await process_frame

	await _check_processing_visual(potato, hold_point, "potato/potato-Sheet.png")
	await _check_processing_visual(carrot, hold_point, "carrot/carrot-Sheet.png")
	_check_container_icon(carrot_container, "carrot/carrot-Sheet.png", "carrot")
	_check_container_icon(potato_container, "potato/potato-Sheet.png", "potato")
	world.queue_free()
	await process_frame
	print("food_processing_sprites_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _check_processing_visual(
	item: RigidBody2D,
	hold_point: Node2D,
	expected_sheet_suffix: String,
) -> void:
	_check(bool(item.TryPickUp(hold_point, 0.0)), "The raw item must be holdable.")
	var static_sprite := item.get_node("Sprite2D") as Sprite2D
	var animated_sprite := item.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_check(static_sprite.visible, "Held raw food must remain static.")
	_check(animated_sprite == null or not animated_sprite.visible, "Held raw food must not play chopping frames.")
	var static_texture := static_sprite.texture as AtlasTexture
	_check(static_texture != null, "Held raw food must use a frame from its authored sheet.")
	_check(
		static_texture != null
		and static_texture.atlas.resource_path.ends_with(expected_sheet_suffix)
		and static_texture.region == Rect2(0, 0, 64, 64),
		"Held raw food must use the first frame of its authored sheet.",
	)
	var definition := item.get("Definition") as Resource
	_check(definition.get("SpriteFrames") == null, "Raw food must not expose an idle animation.")
	var processing_frames := definition.get("ProcessingSpriteFrames") as SpriteFrames
	_check(
		processing_frames != null and processing_frames.get_frame_count(&"idle") == 6,
		"Raw food must expose six process-only chopping frames.",
	)
	var first_frame := processing_frames.get_frame_texture(&"idle", 0) as AtlasTexture
	_check(
		first_frame.atlas.resource_path.ends_with(expected_sheet_suffix),
		"The process animation must use the authored chopping sheet.",
	)

	item.PlayProcessingAnimation(processing_frames)
	await create_timer(0.2).timeout
	animated_sprite = item.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(animated_sprite.visible and not static_sprite.visible, "Processing must switch to the chopping animation.")
	_check(animated_sprite.frame > 0, "The chopping animation must advance while processing.")
	item.RestoreDefinitionVisual()
	_check(static_sprite.visible and not animated_sprite.visible, "Canceling processing must restore the static raw sprite.")


func _check_container_icon(
	container: StaticBody2D,
	expected_sheet_suffix: String,
	label: String,
) -> void:
	var indicator := container.get_node("ItemIndicator") as Sprite2D
	var texture := indicator.texture as AtlasTexture
	_check(texture != null, "The %s box must display an atlas frame." % label)
	_check(
		texture != null
		and texture.atlas.resource_path.ends_with(expected_sheet_suffix)
		and texture.region == Rect2(0, 0, 64, 64),
		"The %s box must display the first frame of its new sheet." % label,
	)
	_check(
		indicator.scale == Vector2.ONE,
		"The %s box icon must fill its label square." % label,
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
