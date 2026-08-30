@tool
class_name NpcTaskRequest
extends RefCounted
## Runtime record of a single dispatched NPC task, tracked by TaskBroker.
##
## Unlike the other ported data models, field names here are snake_case: this
## is a plain runtime object (not a serialized `.tres` surface), and the
## already-ported NPC scripts (task_broker.gd, npc_task_runner.gd) share this
## snake_case, zero-arg-constructible, duck-typed contract: id, generation,
## definition, destination, requested_item, required_tool, status, claimant.
## `NpcTaskRequest.new()` followed by individual field assignment mirrors the
## C# object-initializer construction (`new NpcTaskRequest { Id = ... }`).

enum NpcTaskStatus {
	OPEN,
	CLAIMED,
	COMPLETED,
	CANCELED,
}

var id: int = 0
var generation: int = 0
var definition: NpcTaskDefinition = null
## Typed as the engine base class (Node2D) rather than WorkstationTaskPublisher
## because workstation_task_publisher.gd is ported by another agent and may not
## exist yet when this script is parsed; a missing global class in a type hint
## would be a parse error. Callers still get full dynamic access to the actual
## WorkstationTaskPublisher instance at runtime.
var destination: Node2D = null
var requested_item: PickupItemDefinition = null
var required_tool: PickupItemDefinition = null
var status: NpcTaskStatus = NpcTaskStatus.OPEN
var claimant: Node = null
