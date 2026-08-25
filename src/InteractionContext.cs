using System;
using Godot;

public readonly struct InteractionContext
{
    public InteractionContext(Node2D actor, PickupCarrier carrier)
        : this(
            actor,
            carrier,
            actor.GetParent()
                ?? throw new InvalidOperationException(
                    "An interaction actor must belong to a world item root."
                )
        ) { }

    public InteractionContext(Node2D actor, PickupCarrier carrier, Node worldItemRoot)
    {
        Actor = actor;
        Carrier = carrier;
        WorldItemRoot = worldItemRoot;
    }

    public Node2D Actor { get; }

    public PickupCarrier Carrier { get; }

    public Node WorldItemRoot { get; }
}
