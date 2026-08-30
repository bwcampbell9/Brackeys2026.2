## Applies push-back to rigid bodies and other characters displaced during
## movement, then exponentially decays the residual push velocity every
## physics tick.
##
## Body push receivers are duck-typed: any [Object] that defines
## [code]on_body_pushed()[/code] is notified when a rigid body it owns gets
## pushed. Implementing the method is optional, matching the original
## interface's opt-in behavior.
class_name BodyPusher
extends Node

var _external_velocity: Vector2 = Vector2.ZERO

@export_range(0.0, 1.0, 0.05) var CharacterMotionTransfer: float = 1.0
@export_range(0.0, 1.0, 0.05) var RigidBodyVelocityTransfer: float = 1.0
@export_range(1.0, 100.0, 1.0, "or_greater") var PushDamping: float = 20.0


func move_and_push(actor: CharacterBody2D, requested_velocity: Vector2, delta: float) -> void:
	var movement_velocity := requested_velocity + _external_velocity
	actor.velocity = movement_velocity
	actor.move_and_slide()

	for index in actor.get_slide_collision_count():
		var collision := actor.get_slide_collision(index)
		var push_direction := -collision.get_normal()
		if push_direction.is_zero_approx():
			continue

		var collider := collision.get_collider()
		if collider is RigidBody2D and not collider.freeze:
			_push_rigid_body(collider, movement_velocity, push_direction)
		elif collider is CharacterBody2D and collider != actor:
			_push_character_body(collider, movement_velocity, push_direction)

	_external_velocity *= exp(-PushDamping * delta)
	if _external_velocity.length_squared() < 0.01:
		_external_velocity = Vector2.ZERO


func _push_rigid_body(body: RigidBody2D, requested_velocity: Vector2, push_direction: Vector2) -> void:
	var target_speed := maxf(0.0, requested_velocity.dot(push_direction)) * RigidBodyVelocityTransfer
	var speed_change := target_speed - body.linear_velocity.dot(push_direction)
	if speed_change <= 0.0:
		return

	if body.has_method(&"on_body_pushed"):
		body.on_body_pushed()
	body.apply_central_impulse(push_direction * speed_change * body.mass)


func _push_character_body(body: CharacterBody2D, requested_velocity: Vector2, push_direction: Vector2) -> void:
	var body_pusher: BodyPusher = body.get_node_or_null("BodyPusher")
	if body_pusher == null:
		return

	var push_speed := maxf(0.0, requested_velocity.dot(push_direction)) * CharacterMotionTransfer
	if push_speed <= 0.0:
		return

	body_pusher._receive_push(push_direction * push_speed)


func _receive_push(velocity: Vector2) -> void:
	var push_direction := velocity.normalized()
	var speed_change := velocity.length() - _external_velocity.dot(push_direction)
	if speed_change <= 0.0:
		return

	_external_velocity += push_direction * speed_change
