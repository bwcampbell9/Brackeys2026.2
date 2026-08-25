using Godot;

public partial class InteractionTarget : Area2D
{
    public Node2D TargetOwner => GetParent<Node2D>();

    public InteractionAction? FindAction(
        StringName actionId,
        InteractionInputTrigger trigger,
        InteractionContext context
    )
    {
        foreach (Node child in GetChildren())
        {
            if (
                child is InteractionAction action
                && action.ActionId == actionId
                && action.Trigger == trigger
                && action.IsAvailable(context)
            )
            {
                return action;
            }
        }

        return null;
    }

    public bool HasAction(
        StringName actionId,
        InteractionInputTrigger trigger
    )
    {
        foreach (Node child in GetChildren())
        {
            if (
                child is InteractionAction action
                && action.ActionId == actionId
                && action.Trigger == trigger
            )
            {
                return true;
            }
        }

        return false;
    }
}
