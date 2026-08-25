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
        return (_socket.Item is null && context.Carrier.HeldItem is not null)
            || (
                _socket.Item is not null
                && context.Carrier.HeldItem is null
            );
    }

    public override bool Execute(InteractionContext context)
    {
        return context.Carrier.HeldItem is not null
            ? context.Carrier.TryPlace(_socket)
            : context.Carrier.TryTake(_socket);
    }
}
