@tool
class_name NpcFailurePolicy
extends RefCounted
## Selects which failure mode (if any) an NPC task attempt should roll,
## weighted by personality tendencies and filtered by caller-supplied
## feasibility (e.g. whether an alternative wrong item is even available).

## Returns null when no failure mode should apply, otherwise one of the
## NpcTaskFailureOption.NpcTaskFailureMode values (as an int, per GDScript enum
## representation).
static func select(
	task: NpcTaskDefinition,
	personality: NpcPersonality,
	random: RandomNumberGenerator,
	is_feasible: Callable
) -> Variant:
	assert(task != null, "task must not be null.")
	assert(random != null, "random must not be null.")
	assert(is_feasible.is_valid(), "is_feasible must be a valid callable.")

	if (
		personality == null
		or personality.FailureChance <= 0.0
		or random.randf() >= personality.FailureChance
	):
		return null

	var total_weight := 0.0
	for option in task.FailureOptions:
		if option == null or not is_feasible.call(option.Mode):
			continue
		total_weight += _get_combined_weight(option, personality)

	if total_weight <= 0.0:
		return null

	var selection := random.randf_range(0.0, total_weight)
	for option in task.FailureOptions:
		if option == null or not is_feasible.call(option.Mode):
			continue
		selection -= _get_combined_weight(option, personality)
		if selection <= 0.0:
			return option.Mode

	return null

static func _get_combined_weight(
	option: NpcTaskFailureOption, personality: NpcPersonality
) -> float:
	return maxf(0.0, option.WeightMultiplier) * personality.get_failure_weight(option.Mode)
