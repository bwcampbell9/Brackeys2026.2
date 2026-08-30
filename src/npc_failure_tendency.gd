@tool
class_name NpcFailureTendency
extends Resource
## A personality-level weighting toward a specific NPC task failure mode.

@export var Mode: NpcTaskFailureOption.NpcTaskFailureMode = NpcTaskFailureOption.NpcTaskFailureMode.WRONG_FETCHED_ITEM
@export_range(0, 100, 0.1, "or_greater") var Weight: float = 1.0
