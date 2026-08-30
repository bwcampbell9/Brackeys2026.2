extends GutTest

# Test that customers stay within their navigation area
# and workers stay within their navigation area

func test_customer_navigation_area() -> void:
	var scene = load("res://scenes/level_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	
	# Get the customer navigation region
	var customer_nav_region = scene.get_node("CustomersNavigationRegion2D")
	assert_not_null(customer_nav_region, "Customer navigation region should exist")
	
	var customer = scene.get_node("CustomersNavigationRegion2D/Customer")
	assert_not_null(customer, "Customer should be under CustomerNavigationRegion2D")
	
	var mlady = scene.get_node("CustomersNavigationRegion2D/MladyShubungusCustomer")
	assert_not_null(mlady, "MLady customer should be under CustomerNavigationRegion2D")

func test_worker_navigation_area() -> void:
	var scene = load("res://scenes/level_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	
	# Get the kitchen navigation region
	var kitchen_nav_region = scene.get_node("NavigationRegion2D")
	assert_not_null(kitchen_nav_region, "Kitchen navigation region should exist")
	
	var worker = scene.get_node("NavigationRegion2D/NpcWorker")
	assert_not_null(worker, "Worker should be under NavigationRegion2D")

func test_level_1_score_hud() -> void:
	var scene = load("res://scenes/level_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame

	var hud = scene.get_node_or_null("Hud")
	var score_label = scene.get_node_or_null("Hud/Score") as Label
	assert_not_null(hud, "Level 1 should have a score HUD")
	assert_not_null(score_label, "Level 1 score HUD should have a score label")
	if hud != null:
		assert_eq(hud.GetScore(), 50, "Level 1 score should start at 50")
		hud.ApplyCustomerOrderOutcome(0)
		assert_eq(hud.GetScore(), 55, "A correct Level 1 order should add 5 score")
	if score_label != null:
		assert_eq(score_label.text, "Score: 50 / 100")

func test_customer_wander_bounds() -> void:
	var scene = load("res://scenes/customer.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	
	var controller = scene.get_node("CustomerWanderController")
	assert_not_null(controller, "CustomerWanderController should exist")
	
	# Check that wander bounds are set to the customer navigation area
	var expected_bounds = Rect2(-40, 610, 990, 360)
	assert_eq(controller.WanderBounds, expected_bounds, "WanderBounds should match customer navigation area")
