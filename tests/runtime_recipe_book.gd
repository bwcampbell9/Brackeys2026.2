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

	var previous_page_events := InputMap.action_get_events(&"cookbook_previous_page")
	var next_page_events := InputMap.action_get_events(&"cookbook_next_page")
	_check(
		previous_page_events.size() == 1,
		"Cookbook previous page must have exactly one input binding.",
	)
	_check(
		next_page_events.size() == 1,
		"Cookbook next page must have exactly one input binding.",
	)
	if previous_page_events.size() == 1 and next_page_events.size() == 1:
		_check(
			previous_page_events[0] is InputEventJoypadButton
			and previous_page_events[0].button_index == JOY_BUTTON_DPAD_LEFT,
			"Cookbook previous page must be bound to D-pad left.",
		)
		_check(
			next_page_events[0] is InputEventJoypadButton
			and next_page_events[0].button_index == JOY_BUTTON_DPAD_RIGHT,
			"Cookbook next page must be bound to D-pad right.",
		)

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
	var previous_page_icon := previous_page_button.icon as AtlasTexture
	var next_page_icon := next_page_button.icon as AtlasTexture
	_check(not overlay_root.visible, "The recipe overlay must start hidden.")
	_check(
		previous_page_icon != null
		and previous_page_icon.atlas.resource_path
		== "res://assets/sprites/controller/d-pad-Sheet.png"
		and previous_page_icon.region == Rect2(64, 0, 32, 32),
		"The Back button must show the D-pad left icon.",
	)
	_check(
		next_page_icon != null
		and next_page_icon.atlas.resource_path
		== "res://assets/sprites/controller/d-pad-Sheet.png"
		and next_page_icon.region == Rect2(32, 0, 32, 32),
		"The Next button must show the D-pad right icon.",
	)
	_check(
		previous_page_button.get_theme_font(&"font").resource_path
		== "res://fonts/Pixel Game.otf"
		and next_page_button.get_theme_font(&"font").resource_path
		== "res://fonts/Pixel Game.otf",
		"The cookbook page buttons must use the pixel game font.",
	)
	_check(bool(carrier.try_hold(book)), "The recipe book must be pickable.")
	_check(
		carrier.get("held_item") == book and book.get_parent() == hold_point,
		"The held recipe book must attach to the player's hold point.",
	)
	_check(
		not overlay_root.visible,
		"Holding a closed recipe book must not show the recipe overlay.",
	)
	await _send_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	_check(
		overlay_image.visible and not second_page_image.visible,
		"D-pad input must not turn pages while the cookbook is closed.",
	)

	var transformed_definition = CHOP_TRANSFORMATION.resolve(book.get("Definition"))
	book.set_definition(transformed_definition)
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

	await _send_joypad_button(JOY_BUTTON_B)
	_check(
		sprite.animation == &"open" and sprite.is_playing(),
		"Secondary interaction must start the opening animation while held.",
	)
	_check(
		carrier.get("held_item") == book and book.get_parent() == hold_point,
		"Opening the cookbook with controller B must not throw it.",
	)
	_check(
		open_audio.playing,
		"Opening the recipe book must play the cookbook sound.",
	)
	_check(bool(book.get("is_opening")), "The book must report that it is opening.")
	_check(
		not bool(book.try_secondary_interact()),
		"The book must ignore secondary interaction while opening.",
	)
	await _send_joypad_button(JOY_BUTTON_B)
	_check(
		carrier.get("held_item") == book and book.get_parent() == hold_point,
		"Repeated controller B input while opening must not throw the cookbook.",
	)
	_check(
		not overlay_root.visible,
		"The recipe overlay must remain hidden until opening finishes.",
	)

	await create_timer(0.65).timeout
	_check(sprite.frame == 5, "The opening animation must finish on the open frame.")
	_check(not sprite.is_playing(), "The opening animation must not loop.")
	_check(bool(book.get("is_open")), "The book must remain in its open state.")
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
	await _send_joypad_button(JOY_BUTTON_DPAD_RIGHT)
	_check(
		forward_page_audio.playing and not backward_page_audio.playing,
		"D-pad right must play page turn 1 without playing page turn 2.",
	)
	_check(
		not overlay_image.visible
		and second_page_image.visible
		and not previous_page_button.disabled
		and next_page_button.disabled,
		"D-pad right must display the second page and disable at the last page.",
	)
	await _send_joypad_button(JOY_BUTTON_DPAD_LEFT)
	_check(
		backward_page_audio.playing,
		"D-pad left must play page turn 2.",
	)
	_check(
		overlay_image.visible
		and not second_page_image.visible
		and previous_page_button.disabled
		and not next_page_button.disabled,
		"D-pad left must return to the first page and disable at the first page.",
	)
	forward_page_audio.stop()
	backward_page_audio.stop()
	next_page_button.emit_signal("pressed")
	_check(
		forward_page_audio.playing
		and not overlay_image.visible
		and second_page_image.visible,
		"The Next button must continue to turn to the second page.",
	)
	previous_page_button.emit_signal("pressed")
	_check(
		backward_page_audio.playing
		and overlay_image.visible
		and not second_page_image.visible,
		"The Back button must continue to return to the first page.",
	)

	open_audio.stop()
	await _send_joypad_button(JOY_BUTTON_B)
	_check(sprite.is_playing(), "Secondary interaction must start closing an open book.")
	_check(
		carrier.get("held_item") == book and book.get_parent() == hold_point,
		"Closing the cookbook with controller B must not throw it.",
	)
	_check(
		not open_audio.playing,
		"Closing the recipe book must not restart the cookbook sound.",
	)
	_check(
		close_audio.playing,
		"Closing the recipe book must play the close cookbook sound.",
	)
	_check(bool(book.get("is_closing")), "The book must report that it is closing.")
	_check(
		not bool(book.try_secondary_interact()),
		"The book must ignore secondary interaction while closing.",
	)
	_check(
		overlay_root.visible and overlay_root.position.is_zero_approx(),
		"The recipe overlay must remain visible until closing finishes.",
	)

	await create_timer(0.65).timeout
	_check(sprite.frame == 0, "The closing animation must finish on the closed frame.")
	_check(not sprite.is_playing(), "The closing animation must not loop.")
	_check(not bool(book.get("is_open")), "The book must remain in its closed state.")
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

	await _send_joypad_button(JOY_BUTTON_B)
	await create_timer(0.65).timeout
	_check(sprite.frame == 5, "The closed recipe book must be openable again.")
	_check(bool(book.get("is_open")), "Repeated secondary interaction must toggle the book.")
	_check(
		carrier.get("held_item") == book and book.get_parent() == hold_point,
		"Reopening the cookbook with controller B must keep it held.",
	)
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

	await _send_joypad_button(JOY_BUTTON_A)
	_check(
		carrier.get("held_item") == null,
		"Controller A must still throw the open cookbook.",
	)
	_check(
		book.get_parent() == world and not book.freeze,
		"Throwing must return the recipe book to world physics.",
	)
	await _wait_physics_frames(2)
	_check(book.linear_velocity.length() > 0.0, "Throwing must impart velocity.")
	_check(bool(book.get("is_open")), "Throwing must preserve the open state.")
	await create_timer(0.3).timeout
	_check(not overlay_root.visible, "Throwing must hide the recipe overlay.")
	_check(
		overlay_root.position.y < 0.0,
		"The recipe overlay must leave through the top of the screen.",
	)

	_check(bool(carrier.try_hold(book)), "The open recipe book must be pickable again.")
	_check(
		overlay_root.visible and overlay_root.position.y < 0.0,
		"Picking up an already-open book must immediately show its entering overlay.",
	)
	await create_timer(0.4).timeout
	_check(
		overlay_root.position.is_zero_approx(),
		"An already-open book's overlay must settle in its visible position.",
	)
	_check(bool(carrier.throw()), "The re-picked open recipe book must remain throwable.")
	await create_timer(0.3).timeout
	_check(not overlay_root.visible, "The re-thrown book must hide its recipe overlay.")

	world.queue_free()
	await process_frame
	print("recipe_book_runtime=", "passed" if not _failed else "failed")
	quit(1 if _failed else 0)


func _wait_physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _send_joypad_button(button_index: JoyButton) -> void:
	var press_event := InputEventJoypadButton.new()
	press_event.button_index = button_index
	press_event.pressed = true
	Input.parse_input_event(press_event)
	await physics_frame
	var release_event := InputEventJoypadButton.new()
	release_event.button_index = button_index
	release_event.pressed = false
	Input.parse_input_event(release_event)
	await physics_frame
	await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
