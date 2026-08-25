using Godot;

public enum InteractionRunState
{
    Running,
    Completed,
    Failed,
}

public abstract partial class InteractionAction : Node
{
    [Export]
    public StringName ActionId { get; set; } = new();

    [Export]
    public InteractionInputTrigger Trigger { get; set; }

    public abstract bool IsAvailable(InteractionContext context);

    public virtual bool Execute(InteractionContext context)
    {
        return false;
    }

    public virtual bool Begin(InteractionContext context)
    {
        return false;
    }

    public virtual InteractionRunState UpdateInteraction(
        InteractionContext context,
        double delta
    )
    {
        return InteractionRunState.Completed;
    }

    public virtual void Cancel(InteractionContext context) { }

    protected InteractionTarget GetInteractionTarget()
    {
        return GetParent<InteractionTarget>();
    }
}
