class_name BabyPickupItem
extends PickupItem

## Duck-typed IBodyPushReceiver: exposes on_body_pushed() so BodyPusher can
## suppress the crawl state whenever another body shoves the baby.

const CRAWL_ANIMATION := &"crawl"
const STABBED_ANIMATION := &"stabbed"
const KNIFE_ITEM_ID := &"knife"

@export var CryAudioPath: NodePath = NodePath("CryAudio")
@export var CrySounds: Array[AudioStream] = []
@export_range(10, 300, 1, "or_greater") var MinimumSpeed: float = 35.0
@export_range(10, 300, 1, "or_greater") var MaximumSpeed: float = 70.0
@export_range(0.1, 5, 0.1, "or_greater") var MinimumBurstDuration: float = 0.7
@export_range(0.1, 5, 0.1, "or_greater") var MaximumBurstDuration: float = 1.5
@export_range(0.1, 5, 0.1, "or_greater") var MinimumPauseDuration: float = 0.8
@export_range(0.1, 5, 0.1, "or_greater") var MaximumPauseDuration: float = 2.0
@export var CrawlBounds: Rect2 = Rect2(96.0, 96.0, 768.0, 320.0)
@export_range(0.05, 1, 0.05, "or_greater") var PushSuppressionDuration: float = 0.2
@export_range(0.1, 1000, 0.1, "or_greater") var MinimumLethalKnifeSpeed: float = 30.0

var _sprite: AnimatedSprite2D
var _cry_audio: AudioStreamPlayer2D
var _random: RandomNumberGenerator
var _target_position: Vector2 = Vector2.ZERO
var _state_time: float = 0.0
var _is_crawling: bool = false
var _is_thrown: bool = false
var _is_dead: bool = false
var _push_suppression_remaining: float = 0.0

var is_dead: bool:
	get:
		return _is_dead


func _ready() -> void:
	super._ready()
	_sprite = get_node("AnimatedSprite2D")
	_cry_audio = get_node(CryAudioPath)
	_random = RandomNumberGenerator.new()
	_random.randomize()
	body_entered.connect(_on_body_entered)
	_start_pause()


func _physics_process(delta: float) -> void:
	if _is_dead:
		_stop_dead_motion()
		return

	if not is_available:
		_stop_crawling()
		return

	if _push_suppression_remaining > 0.0:
		_push_suppression_remaining = maxf(0.0, _push_suppression_remaining - delta)
		return

	_state_time -= delta
	if _state_time <= 0.0:
		if _is_crawling:
			_start_pause()
		else:
			_start_burst()

	if not _is_crawling:
		if not _is_thrown:
			linear_velocity = Vector2.ZERO
		return

	var to_target := _target_position - global_position
	if to_target.length_squared() < 256.0:
		_start_pause()
		linear_velocity = Vector2.ZERO
		return

	linear_velocity = to_target.normalized() * _random.randf_range(MinimumSpeed, MaximumSpeed)
	_set_crawl_facing(linear_velocity)


func try_pick_up(hold_point: Node2D, duration: float) -> bool:
	return not _is_dead and super.try_pick_up(hold_point, duration)


func _on_picked_up() -> void:
	_is_thrown = false
	if _is_dead:
		_stop_dead_motion()
		return
	_stop_crawling()
	_play_random_cry()


func _play_random_cry() -> void:
	if CrySounds.is_empty():
		return

	_cry_audio.stream = CrySounds[_random.randi_range(0, CrySounds.size() - 1)]
	_cry_audio.play()


func _on_thrown() -> void:
	if _is_dead:
		_stop_dead_motion()
		return
	_is_thrown = true
	_start_pause()


func on_body_pushed() -> void:
	if _is_dead:
		return
	_push_suppression_remaining = PushSuppressionDuration
	_stop_crawling(false)


func _on_body_entered(body: Node) -> void:
	if _is_dead or not (body is PickupItem):
		return

	var knife := body as PickupItem
	var knife_definition := knife.Definition
	if (
		not knife.is_available
		or knife.is_queued_for_deletion()
		or knife_definition == null
		or knife_definition.Id != KNIFE_ITEM_ID
		or knife.linear_velocity.is_zero_approx()
		or knife.linear_velocity.length_squared() < MinimumLethalKnifeSpeed * MinimumLethalKnifeSpeed
	):
		return

	_is_dead = true
	_is_crawling = false
	_is_thrown = false
	_push_suppression_remaining = 0.0
	_sprite.animation = STABBED_ANIMATION
	_sprite.frame = 0
	_sprite.stop()
	_stop_dead_motion()
	knife.queue_free()


func _stop_dead_motion() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	set_deferred("freeze", true)


func _start_burst() -> void:
	_target_position = Vector2(
		_random.randf_range(CrawlBounds.position.x, CrawlBounds.end.x),
		_random.randf_range(CrawlBounds.position.y, CrawlBounds.end.y)
	)
	_state_time = _random.randf_range(MinimumBurstDuration, MaximumBurstDuration)
	_is_crawling = true
	_is_thrown = false
	_sprite.speed_scale = _random.randf_range(0.8, 1.2)
	_sprite.play(CRAWL_ANIMATION)


func _start_pause() -> void:
	_state_time = _random.randf_range(MinimumPauseDuration, MaximumPauseDuration)
	_stop_crawling()


func _stop_crawling(stop_motion: bool = true) -> void:
	_is_crawling = false
	if stop_motion:
		linear_velocity = Vector2.ZERO
	_sprite.stop()
	_sprite.frame = 0


func _set_crawl_facing(velocity: Vector2) -> void:
	if not is_zero_approx(velocity.x):
		_sprite.flip_h = velocity.x < 0.0

	var facing_rotation := velocity.angle()
	if _sprite.flip_h:
		facing_rotation += PI

	rotation = wrapf(facing_rotation, -PI, PI)
