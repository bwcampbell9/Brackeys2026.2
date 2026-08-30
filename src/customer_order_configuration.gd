class_name CustomerOrderConfiguration
extends CharacterBody2D

## Bitmask flags mirror the C# [Flags] CustomerRequestOptions enum exactly
## (Baby = 1 << 0 through BakedPotato = 1 << 14); integer values are load-bearing
## for already-serialized scene data and must not change.
enum CustomerRequestOptions {
	NONE = 0,
	BABY = 1 << 0,
	CARROT = 1 << 1,
	CARROT_SOUP = 1 << 2,
	CHOPPED_CARROTS = 1 << 3,
	CHOPPED_POTATOES = 1 << 4,
	DUBIOUS_SOUP = 1 << 5,
	KNIFE = 1 << 6,
	POTATO = 1 << 7,
	POTATO_SOUP = 1 << 8,
	RECIPE_BOOK = 1 << 9,
	BAKED_CHOPPED_CARROTS = 1 << 10,
	BAKED_CHOPPED_POTATOES = 1 << 11,
	BAKED_CHOPPED_CARROTS_AND_POTATOES = 1 << 12,
	CARROT_AND_POTATO_SOUP = 1 << 13,
	BAKED_POTATO = 1 << 14,
}

const _KNOWN_REQUESTS := (
	CustomerRequestOptions.BABY
	| CustomerRequestOptions.CARROT
	| CustomerRequestOptions.CARROT_SOUP
	| CustomerRequestOptions.CHOPPED_CARROTS
	| CustomerRequestOptions.CHOPPED_POTATOES
	| CustomerRequestOptions.DUBIOUS_SOUP
	| CustomerRequestOptions.KNIFE
	| CustomerRequestOptions.POTATO
	| CustomerRequestOptions.POTATO_SOUP
	| CustomerRequestOptions.RECIPE_BOOK
	| CustomerRequestOptions.BAKED_CHOPPED_CARROTS
	| CustomerRequestOptions.BAKED_CHOPPED_POTATOES
	| CustomerRequestOptions.BAKED_CHOPPED_CARROTS_AND_POTATOES
	| CustomerRequestOptions.CARROT_AND_POTATO_SOUP
	| CustomerRequestOptions.BAKED_POTATO
)

const _REQUEST_DEFINITIONS := [
	{"option": CustomerRequestOptions.BABY, "path": "res://resources/items/baby.tres"},
	{"option": CustomerRequestOptions.CARROT, "path": "res://resources/items/carrot.tres"},
	{
		"option": CustomerRequestOptions.CARROT_SOUP,
		"path": "res://resources/items/carrot_soup.tres",
	},
	{
		"option": CustomerRequestOptions.CHOPPED_CARROTS,
		"path": "res://resources/items/chopped_carrots.tres",
	},
	{
		"option": CustomerRequestOptions.CHOPPED_POTATOES,
		"path": "res://resources/items/chopped_potatoes.tres",
	},
	{
		"option": CustomerRequestOptions.DUBIOUS_SOUP,
		"path": "res://resources/items/dubious_soup.tres",
	},
	{"option": CustomerRequestOptions.KNIFE, "path": "res://resources/items/knife.tres"},
	{"option": CustomerRequestOptions.POTATO, "path": "res://resources/items/potato.tres"},
	{
		"option": CustomerRequestOptions.POTATO_SOUP,
		"path": "res://resources/items/potato_soup.tres",
	},
	{
		"option": CustomerRequestOptions.RECIPE_BOOK,
		"path": "res://resources/items/recipe_book.tres",
	},
	{
		"option": CustomerRequestOptions.BAKED_CHOPPED_CARROTS,
		"path": "res://resources/items/baked_chopped_carrots.tres",
	},
	{
		"option": CustomerRequestOptions.BAKED_CHOPPED_POTATOES,
		"path": "res://resources/items/baked_chopped_potatoes.tres",
	},
	{
		"option": CustomerRequestOptions.BAKED_CHOPPED_CARROTS_AND_POTATOES,
		"path": "res://resources/items/baked_chopped_vegetables.tres",
	},
	{
		"option": CustomerRequestOptions.CARROT_AND_POTATO_SOUP,
		"path": "res://resources/items/carrot_potato_soup.tres",
	},
	{
		"option": CustomerRequestOptions.BAKED_POTATO,
		"path": "res://resources/items/baked_potato.tres",
	},
]

@export_group("Customer Orders")

@export_flags(
	"Baby",
	"Carrot",
	"CarrotSoup",
	"ChoppedCarrots",
	"ChoppedPotatoes",
	"DubiousSoup",
	"Knife",
	"Potato",
	"PotatoSoup",
	"RecipeBook",
	"BakedChoppedCarrots",
	"BakedChoppedPotatoes",
	"BakedChoppedCarrotsAndPotatoes",
	"CarrotAndPotatoSoup",
	"BakedPotato"
)
var PossibleRequests: int = CustomerRequestOptions.CHOPPED_POTATOES

@export_range(0.0, 300.0, 0.5, "or_greater", "suffix:s")
var MinimumRequestCooldownSeconds: float = 1.0

@export_range(0.0, 300.0, 0.5, "or_greater", "suffix:s")
var MaximumRequestCooldownSeconds: float = 5.0

@export_range(0.1, 300.0, 0.5, "or_greater", "suffix:s")
var OrderDurationSeconds: float = 45.0

@export_group("Dependencies")

@export var TaskPublisherPath: NodePath = NodePath("WorkstationTaskPublisher")


func _ready() -> void:
	if PossibleRequests == CustomerRequestOptions.NONE:
		push_error("%s must allow at least one customer request." % name)
		return
	if (PossibleRequests & ~_KNOWN_REQUESTS) != 0:
		push_error("%s has an unknown customer request option." % name)
		return
	if (
		MinimumRequestCooldownSeconds < 0.0
		or MaximumRequestCooldownSeconds < MinimumRequestCooldownSeconds
	):
		push_error(
			(
				"%s requires a non-negative customer request cooldown range "
				+ "whose maximum is at least its minimum."
			) % name
		)
		return

	var publisher = get_node_or_null(TaskPublisherPath)
	if publisher == null:
		push_error("%s requires a WorkstationTaskPublisher." % name)
		return

	var requests: Array[PickupItemDefinition] = []
	for definition in _REQUEST_DEFINITIONS:
		if (PossibleRequests & definition["option"]) == 0:
			continue

		var request := ResourceLoader.load(definition["path"]) as PickupItemDefinition
		if request == null:
			push_error("Could not load customer request '%s'." % definition["path"])
			return
		requests.append(request)

	publisher.configure_customer_orders(
		requests,
		MinimumRequestCooldownSeconds,
		MaximumRequestCooldownSeconds,
		OrderDurationSeconds
	)
