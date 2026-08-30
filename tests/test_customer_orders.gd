@tool
extends "res://addons/godot_ai/testing/test_suite.gd"

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const MLADY_CUSTOMER_SCENE := preload("res://scenes/mlady_customer.tscn")
const LIL_CUSTOMER_SCENE := preload("res://scenes/lil_customer.tscn")
const LIL_CUSTOMER_2_SCENE := preload("res://scenes/lil_customer_2.tscn")
const ADDITIONAL_REQUESTS := {
	"BakedChoppedCarrots": preload("res://resources/items/baked_chopped_carrots.tres"),
	"BakedChoppedPotatoes": preload("res://resources/items/baked_chopped_potatoes.tres"),
	"BakedChoppedCarrotsAndPotatoes": preload(
		"res://resources/items/baked_chopped_vegetables.tres"
	),
	"CarrotAndPotatoSoup": preload("res://resources/items/carrot_potato_soup.tres"),
	"BakedPotato": preload("res://resources/items/baked_potato.tres"),
}


func suite_name() -> String:
	return "customer_orders"


func test_customers_expose_request_difficulty_on_their_roots() -> void:
	var customer_contracts := [
		{"scene": CUSTOMER_SCENE, "request": 16},
		{"scene": MLADY_CUSTOMER_SCENE, "request": 8},
		{"scene": LIL_CUSTOMER_SCENE, "request": 2},
		{"scene": LIL_CUSTOMER_2_SCENE, "request": 64},
	]
	for contract: Dictionary in customer_contracts:
		var customer := track((contract.scene as PackedScene).instantiate()) as CharacterBody2D
		assert_eq(
			customer.get_script().resource_path,
			"res://src/CustomerOrderConfiguration.cs",
		)
		assert_eq(int(customer.get("PossibleRequests")), int(contract.request))
		assert_true(
			is_equal_approx(float(customer.get("MinimumRequestCooldownSeconds")), 1.0)
		)
		assert_true(
			is_equal_approx(float(customer.get("MaximumRequestCooldownSeconds")), 5.0)
		)
		assert_true(is_equal_approx(float(customer.get("OrderDurationSeconds")), 45.0))

	var customer := track(CUSTOMER_SCENE.instantiate()) as CharacterBody2D
	var possible_requests_property: Dictionary = {}
	for property: Dictionary in customer.get_property_list():
		if property.name == &"PossibleRequests":
			possible_requests_property = property
			break
	assert_false(possible_requests_property.is_empty())
	if not possible_requests_property.is_empty():
		assert_eq(
			int(possible_requests_property.hint),
			PROPERTY_HINT_FLAGS,
			"PossibleRequests must be a true Inspector multi-select.",
		)
		var hint := String(possible_requests_property.hint_string)
		for option_name: String in [
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
			"BakedPotato",
		]:
			assert_true(hint.contains(option_name))

	var expected_ids := {
		"BakedChoppedCarrots": &"cooked_chopped_carrots",
		"BakedChoppedPotatoes": &"cooked_chopped_potatoes",
		"BakedChoppedCarrotsAndPotatoes": &"baked_chopped_vegetables",
		"CarrotAndPotatoSoup": &"carrot_potato_soup",
		"BakedPotato": &"cooked_potato",
	}
	for option_name: String in ADDITIONAL_REQUESTS:
		var definition := ADDITIONAL_REQUESTS[option_name] as Resource
		assert_true(definition != null)
		if definition != null:
			assert_eq(definition.get("Id"), expected_ids[option_name])
			assert_true(
				definition.get("Texture") != null or definition.get("SpriteFrames") != null
			)
