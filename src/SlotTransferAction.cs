using System;
using System.Collections.Generic;
using Godot;
using Godot.Collections;

public partial class SlotTransferAction : InteractionAction
{
    private PickupSocket _socket = null!;
    private readonly List<PickupSocket> _sockets = new();
    private WorkstationTaskPublisher? _taskPublisher;
    private OvenCookingController? _cookingController;

    public SlotTransferAction()
    {
        ActionId = InteractionActionIds.Transfer;
        Trigger = InteractionInputTrigger.Tap;
    }

    [Export]
    public NodePath SocketPath { get; set; } = new("../../PickupSocket");

    [Export]
    public Array<NodePath> AdditionalSocketPaths { get; set; } = new();

    [Export]
    public PickupItemDefinition? AcceptedItem { get; set; }

    [Export]
    public NodePath TaskPublisherPath { get; set; } = new();

    [Export]
    public NodePath CookingControllerPath { get; set; } = new();

    public override void _Ready()
    {
        _socket =
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "SlotTransferAction requires a valid pickup socket path."
            );
        _sockets.Add(_socket);
        foreach (NodePath path in AdditionalSocketPaths)
        {
            _sockets.Add(
                GetNodeOrNull<PickupSocket>(path)
                ?? throw new InvalidOperationException(
                    $"SlotTransferAction requires pickup socket '{path}'."
                )
            );
        }
        if (!TaskPublisherPath.IsEmpty)
        {
            _taskPublisher =
                GetNodeOrNull<WorkstationTaskPublisher>(TaskPublisherPath)
                ?? throw new InvalidOperationException(
                    "SlotTransferAction requires a valid task publisher path."
                );
        }
        if (!CookingControllerPath.IsEmpty)
        {
            _cookingController =
                GetNodeOrNull<OvenCookingController>(CookingControllerPath)
                ?? throw new InvalidOperationException(
                    "SlotTransferAction requires a valid cooking controller path."
                );
        }
    }

    public override bool IsAvailable(InteractionContext context)
    {
        if (
            _taskPublisher is not null
            && !_taskPublisher.IsAcceptingCustomerDelivery
        )
        {
            return false;
        }

        PickupItem? heldItem = context.Carrier.HeldItem;
        return heldItem is not null
            ? FindPlacementSocket(heldItem) is not null
            : FindTakeSocket() is not null;
    }

    public override bool Execute(InteractionContext context)
    {
        PickupItem? heldItem = context.Carrier.HeldItem;
        PickupSocket? socket = heldItem is not null
            ? FindPlacementSocket(heldItem)
            : FindTakeSocket();
        if (socket is null)
        {
            return false;
        }

        return heldItem is not null
            ? context.Carrier.TryPlace(socket)
            : context.Carrier.TryTake(socket);
    }

    private PickupSocket? FindPlacementSocket(PickupItem item)
    {
        if (
            !IsAccepted(item)
            || (
                _cookingController is not null
                && !_cookingController.CanAccept(item)
            )
        )
        {
            return null;
        }

        foreach (PickupSocket socket in _sockets)
        {
            if (!socket.IsLocked && socket.Item is null)
            {
                return socket;
            }
        }

        return null;
    }

    private PickupSocket? FindTakeSocket()
    {
        foreach (PickupSocket socket in _sockets)
        {
            if (!socket.IsLocked && socket.Item is not null)
            {
                return socket;
            }
        }

        return null;
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
