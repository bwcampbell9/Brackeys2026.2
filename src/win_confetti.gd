class_name WinConfetti
extends CanvasLayer

class Piece:
	var visual: ColorRect
	var velocity: Vector2 = Vector2.ZERO
	var angular_velocity: float = 0.0
	var flutter_speed: float = 0.0
	var flutter_phase: float = 0.0

const _PIECE_COUNT := 72
const _LIFETIME := 2.25
const _FADE_DURATION := 0.4
const _GRAVITY := 700.0
const _PALETTE: Array[Color] = [
	Color("ff4d6d"),
	Color("ffca3a"),
	Color("8ac926"),
	Color("00bbf9"),
	Color("9b5de5"),
	Color("ff70a6"),
]

var _pieces: Array[Piece] = []
var _elapsed: float = 0.0


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func burst(origin: Vector2) -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()

	for index in range(_PIECE_COUNT):
		var piece_size := Vector2(
			random.randf_range(6.0, 12.0),
			random.randf_range(10.0, 20.0)
		)
		var visual := ColorRect.new()
		visual.color = _PALETTE[index % _PALETTE.size()]
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.position = origin - (piece_size * 0.5)
		visual.pivot_offset = piece_size * 0.5
		visual.rotation = random.randf_range(-PI, PI)
		visual.size = piece_size
		add_child(visual)

		var angle := deg_to_rad(random.randf_range(-165.0, -15.0))
		var speed := random.randf_range(280.0, 560.0)
		var piece := Piece.new()
		piece.visual = visual
		piece.velocity = Vector2.from_angle(angle) * speed
		piece.angular_velocity = random.randf_range(-9.0, 9.0)
		piece.flutter_speed = random.randf_range(8.0, 16.0)
		piece.flutter_phase = random.randf_range(0.0, TAU)
		_pieces.append(piece)


func _process(delta: float) -> void:
	var frame_seconds := delta
	_elapsed += frame_seconds
	var alpha := clampf((_LIFETIME - _elapsed) / _FADE_DURATION, 0.0, 1.0)

	for piece in _pieces:
		piece.velocity += Vector2.DOWN * _GRAVITY * frame_seconds
		piece.visual.position += piece.velocity * frame_seconds
		piece.visual.rotation += piece.angular_velocity * frame_seconds
		piece.visual.scale = Vector2(
			maxf(0.15, absf(sin((_elapsed * piece.flutter_speed) + piece.flutter_phase))),
			1.0
		)
		piece.visual.modulate = Color(1.0, 1.0, 1.0, alpha)

	if _elapsed >= _LIFETIME:
		set_process(false)
		queue_free()
