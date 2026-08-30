extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const RECIPE_BOOK_SCENE := preload("res://scenes/recipe_book_item.tscn")
const CHOP_TRANSFORMATION := preload("res://resources/transformations/chop.tres")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var book := RECIPE_BOOK_SCENE.instantiate() as RigidBody2D
	world.add_child(player)
	world.add_child(book)
	root.add_child(world)
	await process_frame
	await process_frame
	await physics_frame

	var carrier := player.get_node("PickupCarrier")
	var hold_point := player.get_node("PickupCarrier/HoldPoint") as Node2D
	var sprite := book.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var open_audio := book.get_node("OpenCookbookAudio") as AudioStreamPlayer2D
	var close_audio := book.get_node("CloseCookbookAudio") as AudioStreamPlayer2D
	var forward_page_audio := book.get_node("ForwardPageAudio") as AudioStreamPlayer2D
	var backward_page_audio := book.get_node("BackwardPageAudio") as AudioStreamPlayer2D
	var overlay_root := book.get_node("RecipeOverlay/OverlayRoot") as Control
	var overlay_image := book.get_node("RecipeOverlay/OverlayRoot/Book") as TextureRect
	var second_page_image := book.get_node("RecipeOverlay/OverlayRoot/PageTwo") as TextureRect
	var previous_page_button := book.get_node("RecipeOverlay/OverlayRoot/PreviousPageButton") as Button
	var next_page_button := book.get_node("RecipeOverlay/OverlayRoot/NextPageButton") as Button
	_check(not overlay_root.visible, "The recipe overlay must start hidden.")
	_check(bool(carrier.TryHold(book)), "The recipe book must be pickable.")
	_check(
		carrier.get("HeldItem") == book and book.get_parent() == hold_point,
		"The held recipe book must attach to the player's hold point.",
	)
	_check(
		not overlay_root.visible,
		"Holding a closed recipe book must not show the recipe overlay.",
	)

	var transformed_definition = CHOP_TRANSFORMATION.Resolve(book.get("Definition"))
	book.SetDefinition(transformed_definition)
	_check(
		sprite.material != null and overlay_image.material == sprite.material,
		"The recipe overlay must share the held item's transformation material.",
	)
	_check(
		overlay_image.modulate == sprite.modulate,
		"The recipe overlay must share the held item's transformation color.",
	)
	var fracture_shader := (sprite.material as ShaderMaterial).shader
	_check(
		fracture_shader.code.contains("(UV - REGION_RECT.xy) / REGION_RECT.zw")
		and fracture_shader.code.contains(
			"REGION_RECT.xy + source_uv * REGION_RECT.zw"
		),
		"The fracture shader must calculate cuts in atlas-frame-local UV space.",
	)
	_check(sprite.frame == 0 and not sprite.is_playing(), "The book must start closed.")

	Input.action_press("secondary_interact")
	await _wait_physics_frames(2)
	Input.action_release("secondary_interact")
	_check(
		sprite.animation == &"open" and sprite.is_playing(),
		"Secondary interaction must start the opening animation while held.",
	)
	_check(
		open_audio.playing,
		"Opening the recipe book must play the cookbook sound.",
	)
	_check(bool(book.get("IsOpening")), "The book must report that it is opening.")
	_check(
		not bool(book.TrySecondaryInteract()),
		"The book must ignore secondary interaction while opening.",
	)
	_check(
		not overlay_root.visible,
		"The recipe overlay must remain hidden until opening finishes.",
	)

	await create_timer(0.65).timeout
	_check(sprite.frame == 5, "The opening animation must finish on the open frame.")
	_check(not sprite.is_playing(), "The opening animation must not loop.")
	_check(bool(book.get("IsOpen")), "The book must remain in its open state.")
	_check(
		book.get_parent() == hold_point,
		"The open recipe book must remain in the player's hands.",
	)
	_check(
		overlay_root.visible and overlay_root.position.y < 0.0,
		"The recipe overlay must enter from above after opening finishes.",
	)
	await create_timer(0.4).timeout
	_check(
		overlay_root.position.is_zero_approx(),
		"The recipe overlay must settle in its visible position.",
	)
	_check(
		overlay_image.visible
		and not second_page_image.visible
		and previous_page_button.disabled
		and not next_page_button.disabled,
		"Opening the recipe book must display its first page with only Next available.",
	)
	next_page_button.emit_signal("pressed")
	_check(
		forward_page_audio.playing and not backward_page_audio.playing,
		"Next must play page turn 1 without playing page turn 2.",
	)
	_check(
		not overlay_image.visible
		and second_page_image.visible
		and not previous_page_button.disabled
		and next_page_button.disabled,
		"Next must display the second page and disable at the last page.",
	)
	previous_page_button.emit_signal("pressed")
	_check(
		backward_page_audio.playing,
		"Back must play page turn 2.",
	)
	_check(
		overlay_image.visible
		and not second_page_image.visible
		and previous_page_button.disabled
		and not next_page_button.disabled,
		"Back must return to the first page and disable at the first page.",
	)

	var open_audio_position := open_audio.get_playback_position()
	Input.action_press("secondary_interact")
	await _wait_physics_frames(2)
	Input.action_release("secondary_interact")
	_check(sprite.is_playing(), "Secondary interaction must start closing an open book.")
	_check(
		open_audio.get_playback_position() > open_audio_position,
		"Closing the recipe book must not restart the cookbook sound.",
	)
	_check(
		close_audio.playing,
		"Closing the recipe book must play the close cookbook sound.",
	)
	_check(bool(book.get("IsClosing")), "The book must report that it is closing.")
	_check(
		not bool(book.TrySecondaryInteract()),
		"The book must ignore secondary interaction while closing.",
	)
	_check(
		overlay_root.visible and overlay_root.position.is_zero_approx(),
		"The recipe overlay must remain visible until closing finishes.",
	)

	await create_timer(0.65).timeout
	_check(sprite.frame == 0, "The closing animation must finish on the closed frame.")
	_check(not sprite.is_playing(), "The closing animation must not loop.")
	_check(not bool(book.get("IsOpen")), "The book must remain in its closed state.")
	_check(
		book.get_parent() == hold_point,
		"The closed recipe book must remain in the player's hands.",
	)
	_check(
		overlay_root.visible and overlay_root.position.y < 0.0,
		"The recipe overlay must leave from the top after closing finishes.",
	)
	await create_timer(0.3).timeout
	_check(not overlay_root.visible, "A closed book must keep the recipe overlay hidden.")

	Input.action_press("secondary_interact")
	await _wait_physics_frames(2)
	Input.action_release("secondary_interact")
	await create_timer(0.65).timeout
	_check(sprite.frame == 5, "The closed recipe book must be openable again.")
	_check(bool(book.get("IsOpen")), "Repeated secondary interaction must toggle the book.")
	await create_timer(0.4).timeout
	_check(
		overlay_root.visible and overlay_root.position.is_zero_approx(),
		"Reopening the held book must show the recipe overlay again.",
	)
	_check(
		overlay_image.visible
		and not second_page_image.visible
		and previous_page_button.disabled
		and not next_page_button.disabled,
		"Reopening the recipe book must reset it to the first page.",
	)

	_check(bool(carrier.Throw()), "The open recipe book must remain throwable.")
	_check(
		book.get_parent() == world and not book.freeze,
		"Throwing must return the recipe book to world physics.",
	)
	await _wait_physics_frames(2)
	_check(book.linear_velocity.length() > 0.0, "Throwing must impart velocity.")
	_check(bool(book.get("IsOpen")), "Throwing must preserve the open state.")
	await create_timer(0.3).timeout
	_check(not overlay_root.visible, "Throwing must hide the recipe overlay.")
	_check(
		overlay_root.position.y < 0.0,
		"The recipe overlay must leave through the top of the screen.",
	)

	_check(bool(carrier.TryHold(book)), "The open recipe book must be pickable again.")
	_check(
		overlay_root.visible and overlay_root.position.y < 0.0,
		"Picking up an already-open book must immediately show its entering overlay.",
	)
	await create_timer(0.4).timeout
	_check(
		overlay_root.position.is_zero_approx(),
		"An already-open book's overlay must settle in its visible position.",
	)
	_check(bool(carrier.Throw()), "The re-picked open recipe book must remain throwable.")
	await create_timer(0.3).timeout
	_check(not overlay_root.visible, "The re-thrown book must hide its recipe overlay.")

	world.queue_free()
	await process_frame
	print("recipe_book_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
