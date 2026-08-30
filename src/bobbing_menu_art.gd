class_name BobbingMenuArt
extends TextureRect

@export_range(0, 20, 0.5, "or_greater") var Amplitude: float = 4.0
@export_range(0.5, 10, 0.1, "or_greater") var Period: float = 4.0
@export_range(0, 6.283, 0.01) var Phase: float = 0.0

var _rest_position: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0


func _ready() -> void:
	_rest_position = position
	Period = maxf(Period, 0.5)


func _process(delta: float) -> void:
	_elapsed += delta
	var offset := sin((_elapsed * TAU / Period) + Phase) * Amplitude
	position = _rest_position + Vector2.UP * offset
