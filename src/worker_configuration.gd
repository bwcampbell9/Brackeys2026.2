class_name WorkerConfiguration
extends CharacterBody2D

@export_group("Worker Difficulty")

@export_range(0, 1, 0.01) var ErrorRate: float = 0.6

@export_group("Dependencies")

@export var TaskRunnerPath: NodePath = NodePath("NpcTaskRunner")


func _ready() -> void:
	if ErrorRate < 0.0 or ErrorRate > 1.0:
		push_error("%s requires a worker error rate between 0 and 1." % name)
		return

	var runner := get_node_or_null(TaskRunnerPath) as NpcTaskRunner
	if runner == null:
		push_error("%s requires an NpcTaskRunner." % name)
		return

	var source_personality: Resource = runner.Personality
	if source_personality == null:
		push_error("%s requires an NpcPersonality." % name)
		return

	## instance_personality is left untyped: NpcPersonality belongs to the data
	## foundations reservation and its FailureChance export is not a member of
	## the base Resource type.
	var instance_personality = source_personality.duplicate(true)
	instance_personality.FailureChance = ErrorRate
	runner.Personality = instance_personality
