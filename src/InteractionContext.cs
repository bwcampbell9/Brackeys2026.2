using Godot;

public readonly struct InteractionContext
{
    public InteractionContext(Node2D actor, PickupCarrier carrier)
    {
        Actor = actor;
        Carrier = carrier;
    }

    public Node2D Actor { get; }

    public PickupCarrier Carrier { get; }
}
