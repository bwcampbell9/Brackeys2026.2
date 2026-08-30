@tool
class_name NpcTaskDefinition
extends Resource
## Authored definition of a kitchen task an NPC worker can be assigned
## (e.g. fetch an ingredient, perform a workstation action).

enum NpcTaskKind {
	FETCH,
	ACTION,
}

@export var Id: StringName = &""
@export var Kind: NpcTaskKind = NpcTaskKind.FETCH
@export var RequiredTags: Array[StringName] = []
@export var FailureOptions: Array[NpcTaskFailureOption] = []
@export var Priority: int = 0
