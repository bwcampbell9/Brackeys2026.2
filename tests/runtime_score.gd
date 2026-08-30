extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_packed(MAIN_SCENE)
	await process_frame
	await process_frame

	var runner := current_scene.get_node("NpcWorker/NpcTaskRunner")
	var hud := current_scene.get_node("Hud")
	var score_label := current_scene.get_node("Hud/Score") as Label
	var game_over_controller := current_scene.get_node("GameOverController")
	var overlay := game_over_controller.get_child(0) as ColorRect
	runner.process_mode = Node.PROCESS_MODE_DISABLED

	_check(int(hud.GetScore()) == 50, "Score must start at 50.")
	hud.ApplyCustomerOrderOutcome(0)
	_check(int(hud.GetScore()) == 55, "A correct order must add 5 score.")
	var popup := hud.get_node_or_null("ScoreChange") as Label
	_check(popup != null and popup.text == "+5", "A score gain must show its delta.")
	if popup != null:
		var popup_start_y := popup.position.y
		_check(
			popup_start_y > score_label.position.y,
			"The score delta must appear below the score.",
		)
		await create_timer(0.15, true, false, true).timeout
		_check(
			score_label.text != "Score: 50 / 100"
				and score_label.text != "Score: 55 / 100",
			"The score display must tween through intermediate numbers.",
		)
		await create_timer(0.2, true, false, true).timeout
		_check(
			popup.position.y < popup_start_y,
			"The score delta must rise toward the score.",
		)
	await create_timer(0.55, true, false, true).timeout
	_check(score_label.text == "Score: 55 / 100", "The score display must reach 55.")
	_check(
		hud.get_node_or_null("ScoreChange") == null,
		"The score delta must disappear after reaching the score.",
	)
	hud.ApplyCustomerOrderOutcome(1)
	_check(int(hud.GetScore()) == 51, "A wrong order must remove 4 score.")
	hud.ApplyCustomerOrderOutcome(2)
	_check(int(hud.GetScore()) == 43, "A missed order must remove 8 score.")

	for _index in range(20):
		hud.ApplyCustomerOrderOutcome(0)
	_check(int(hud.GetScore()) == 100, "Score must remain capped at 100.")

	for _index in range(23):
		hud.ApplyCustomerOrderOutcome(1)
	_check(int(hud.GetScore()) == 8, "Wrong orders must each remove 4 score.")
	_check(not paused, "Game over must not start above zero score.")

	hud.ApplyCustomerOrderOutcome(2)
	_check(int(hud.GetScore()) == 0, "A missed order must clamp score to zero.")
	_check(paused, "Reaching zero score must pause for game over.")
	_check(overlay.visible, "Reaching zero score must show the game-over overlay.")

	hud.ApplyCustomerOrderOutcome(1)
	_check(int(hud.GetScore()) == 0, "Score must remain clamped at zero.")
	await create_timer(0.9, true, false, true).timeout
	_check(
		score_label.text == "Score: 0 / 100",
		"The score display must finish its tween while game over is paused.",
	)
	var remaining_popups := 0
	for child in hud.get_children():
		if child is Label and str(child.name).begins_with("ScoreChange"):
			remaining_popups += 1
	_check(
		remaining_popups == 0,
		"Score popups must clean up while game over is paused.",
	)

	paused = false
	current_scene.queue_free()
	await process_frame
	print("score_runtime=", "failed" if _failed else "passed")
	quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
