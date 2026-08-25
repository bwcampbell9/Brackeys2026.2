using Godot;

public enum NpcTaskStatus
{
    Open,
    Claimed,
    Completed,
    Canceled,
}

public sealed class NpcTaskRequest
{
    public required long Id { get; init; }

    public required int Generation { get; init; }

    public required NpcTaskDefinition Definition { get; init; }

    public required WorkstationTaskPublisher Destination { get; init; }

    public PickupItemDefinition? RequestedItem { get; init; }

    public PickupItemDefinition? RequiredTool { get; init; }

    public NpcTaskStatus Status { get; internal set; } = NpcTaskStatus.Open;

    public Node? Claimant { get; internal set; }
}
