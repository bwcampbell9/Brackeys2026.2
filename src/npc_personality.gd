@tool
class_name NpcPersonality
extends Resource
## Configures how often, and toward which failure modes, an NPC worker fails
## tasks it attempts.

@export_range(0, 1, 0.01) var FailureChance: float = 0.6
@export var FailureTendencies: Array[NpcFailureTendency] = []

func get_failure_weight(mode: NpcTaskFailureOption.NpcTaskFailureMode) -> float:
	var weight := 0.0
	for tendency in FailureTendencies:
		if tendency != null and tendency.Mode == mode:
			weight += maxf(0.0, tendency.Weight)

	return weight
