extends StaticBody2D

# Deliberately no `class_name` here: Godot's built-in Control node already
# claims the global name `Container`, so this script is only ever referenced
# by its scene path (res://src/container.gd), matching how other systems
# already look it up via NodePath rather than a static type.

const IDLE_ANIMATION := &"idle"
const TAKE_ANIMATION := &"take"

var _action: PickupContainerAction
var _item_source: ContainerItemSource
var _item_indicator: Sprite2D
var _sprite: AnimatedSprite2D

@export var PickupScene: PackedScene
@export var ItemDefinition: PickupItemDefinition
@export_range(0.1, 2, 0.05, "or_greater") var ItemIndicatorScaleMultiplier: float = 0.5


func _ready() -> void:
	if PickupScene == null or ItemDefinition == null:
		push_error("Container requires both a pickup scene and an item definition.")
		return

	_action = get_node("InteractionTarget/PickupContainerAction")
	_item_source = get_node("NpcItemSource")
	_item_indicator = get_node("ItemIndicator")
	_sprite = get_node("AnimatedSprite2D")

	_action.PickupScene = PickupScene
	_action.AcceptedItem = ItemDefinition
	_action.item_transferred.connect(_play_take_animation)
	_sprite.animation_finished.connect(_on_animation_finished)
	_item_source.ItemDefinition = ItemDefinition
	_apply_item_indicator(ItemDefinition)


func _exit_tree() -> void:
	if is_instance_valid(_action) and _action.item_transferred.is_connected(_play_take_animation):
		_action.item_transferred.disconnect(_play_take_animation)

	if is_instance_valid(_sprite) and _sprite.animation_finished.is_connected(_on_animation_finished):
		_sprite.animation_finished.disconnect(_on_animation_finished)


func _play_take_animation() -> void:
	_sprite.play(TAKE_ANIMATION)


func _on_animation_finished() -> void:
	if _sprite.animation == TAKE_ANIMATION:
		_sprite.play(IDLE_ANIMATION)


func _apply_item_indicator(definition: PickupItemDefinition) -> void:
	var collision: CollisionShape2D = get_node("CollisionShape2D")
	_item_indicator.position = collision.position
	_item_indicator.texture = definition.get_display_texture()
	_item_indicator.material = definition.VisualMaterial
	_item_indicator.modulate = definition.Modulate
	_item_indicator.scale = definition.VisualScale * ItemIndicatorScaleMultiplier
	_item_indicator.visible = _item_indicator.texture != null
