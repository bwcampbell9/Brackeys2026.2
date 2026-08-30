@tool
class_name NpcTaskFailureOption
extends Resource
## A single weighted failure mode an NPC task can roll during execution.

enum NpcTaskFailureMode {
	WRONG_FETCHED_ITEM,
}

@export var Mode: NpcTaskFailureMode = NpcTaskFailureMode.WRONG_FETCHED_ITEM
@export_range(0, 100, 0.1, "or_greater") var WeightMultiplier: float = 1.0
