using Godot;

public interface IItemSource
{
    Node2D SourceNode { get; }

    PickupItemDefinition? AvailableDefinition { get; }

    bool IsSourceAvailable { get; }

    bool CanReturnItem { get; }

    Vector2 ApproachPosition { get; }

    bool TryAcquire(InteractionContext context);

    bool TryReturn(InteractionContext context);
}
