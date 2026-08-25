using System;
using Godot;

public partial class TimedItemProcessAction : InteractionAction
{
    private float _elapsed;
    private PickupSocket _socket = null!;

    public TimedItemProcessAction()
    {
        ActionId = InteractionActionIds.Process;
        Trigger = InteractionInputTrigger.Hold;
    }

    [Signal]
    public delegate void ProcessingStartedEventHandler();

    [Signal]
    public delegate void ProgressChangedEventHandler(float progress);

    [Signal]
    public delegate void ProcessingCanceledEventHandler();

    [Signal]
    public delegate void ProcessingCompletedEventHandler(PickupItem item);

    [Export]
    public NodePath SocketPath { get; set; } = new("../../PickupSocket");

    [Export]
    public ProcessingRecipe? Recipe { get; set; }

    public float Progress =>
        Recipe is null || Recipe.Duration <= 0.0f
            ? 0.0f
            : Mathf.Clamp(_elapsed / Recipe.Duration, 0.0f, 1.0f);

    public override void _Ready()
    {
        _socket =
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "TimedItemProcessAction requires a valid pickup socket path."
            );
    }

    public override bool IsAvailable(InteractionContext context)
    {
        PickupItem? item = _socket.Item;
        return context.Carrier.HeldItem is null
            && item is not null
            && Recipe is not null
            && Recipe.Matches(item);
    }

    public override bool Begin(InteractionContext context)
    {
        if (!IsAvailable(context))
        {
            return false;
        }

        _elapsed = 0.0f;
        EmitSignal(SignalName.ProcessingStarted);
        EmitSignal(SignalName.ProgressChanged, 0.0f);
        return true;
    }

    public override InteractionRunState UpdateInteraction(
        InteractionContext context,
        double delta
    )
    {
        PickupItem? item = _socket.Item;
        if (
            item is null
            || Recipe is null
            || Recipe.Output is null
            || !IsAvailable(context)
        )
        {
            return InteractionRunState.Failed;
        }

        _elapsed += (float)delta;
        EmitSignal(SignalName.ProgressChanged, Progress);
        if (_elapsed < Recipe.Duration)
        {
            return InteractionRunState.Running;
        }

        item.SetDefinition(Recipe.Output);
        _elapsed = 0.0f;
        EmitSignal(SignalName.ProgressChanged, 1.0f);
        EmitSignal(SignalName.ProcessingCompleted, item);
        return InteractionRunState.Completed;
    }

    public override void Cancel(InteractionContext context)
    {
        _elapsed = 0.0f;
        EmitSignal(SignalName.ProgressChanged, 0.0f);
        EmitSignal(SignalName.ProcessingCanceled);
    }
}
