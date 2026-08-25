using System;
using System.Collections.Generic;
using Godot;

public partial class KitchenTaskSystem : Node
{
    private TaskBroker _broker = null!;
    private ItemSourceCatalog _catalog = null!;
    private Node _kitchenRoot = null!;

    public override void _Ready()
    {
        _broker = GetNode<TaskBroker>("TaskBroker");
        _catalog = GetNode<ItemSourceCatalog>("ItemSourceCatalog");
        _kitchenRoot =
            GetParent()
            ?? throw new InvalidOperationException(
                "KitchenTaskSystem requires an owning kitchen root."
            );
        _catalog.Configure(_kitchenRoot);
        Callable.From(WireParticipants).CallDeferred();
    }

    private void WireParticipants()
    {
        Stack<Node> pending = new();
        foreach (Node child in _kitchenRoot.GetChildren())
        {
            pending.Push(child);
        }

        while (pending.Count > 0)
        {
            Node node = pending.Pop();
            if (node is WorkstationTaskPublisher publisher)
            {
                publisher.Configure(_broker);
            }
            if (node is NpcTaskRunner runner)
            {
                runner.Configure(_broker, _catalog);
            }

            foreach (Node child in node.GetChildren())
            {
                pending.Push(child);
            }
        }
    }
}
