using System;
using Godot;

public partial class SlotTransferAction : InteractionAction
{
    private PickupSocket _socket = null!;

    public SlotTransferAction()
    {
        ActionId = InteractionActionIds.Transfer;
        Trigger = InteractionInputTrigger.Tap;
    }

    [Export]
    public NodePath SocketPath { get; set; } = new("../../PickupSocket");

    [Export]
    public PickupItemDefinition? AcceptedItem { get; set; }

    public override void _Ready()
    {
        _socket =
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "SlotTransferAction requires a valid pickup socket path."
            );
    }

    public override bool IsAvailable(InteractionContext context)
    {
        PickupItem? heldItem = context.Carrier.HeldItem;
        return (
                _socket.Item is null
                && heldItem is not null
                && IsAccepted(heldItem)
            )
            || (
                _socket.Item is not null
                && heldItem is null
            );
    }

    public override bool Execute(InteractionContext context)
    {
        return context.Carrier.HeldItem is not null
            ? context.Carrier.TryPlace(_socket)
            : context.Carrier.TryTake(_socket);
    }

    private bool IsAccepted(PickupItem item)
    {
        return AcceptedItem is null
            || (
                item.Definition is not null
                && item.Definition.Id == AcceptedItem.Id
            );
    }
}
