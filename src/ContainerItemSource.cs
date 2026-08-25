using System;
using Godot;

public partial class ContainerItemSource : Node2D, IItemSource
{
    private PickupContainerAction _action = null!;

    [Export]
    public NodePath ActionPath { get; set; } =
        new("../InteractionTarget/PickupContainerAction");

    [Export]
    public PickupItemDefinition? ItemDefinition { get; set; }

    public Node2D SourceNode => this;

    public PickupItemDefinition? AvailableDefinition => ItemDefinition;

    public bool IsSourceAvailable =>
        ItemDefinition is not null
        && GodotObject.IsInstanceValid(_action)
        && _action.PickupScene is not null;

    public bool CanReturnItem => true;

    public Vector2 ApproachPosition => GlobalPosition;

    public override void _Ready()
    {
        _action =
            GetNodeOrNull<PickupContainerAction>(ActionPath)
            ?? throw new InvalidOperationException(
                "ContainerItemSource requires a valid pickup container action."
            );
        AddToGroup(ItemSourceCatalog.ItemSourceGroup);
    }

    public bool TryAcquire(InteractionContext context)
    {
        return context.Carrier.HeldItem is null
            && _action.IsAvailable(context)
            && _action.Execute(context);
    }

    public bool TryReturn(InteractionContext context)
    {
        return context.Carrier.HeldItem is not null
            && _action.IsAvailable(context)
            && _action.Execute(context);
    }
}
