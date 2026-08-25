using System;
using Godot;

public partial class TimedItemProcessAction : InteractionAction
{
    private float _elapsed;
    private PickupSocket _socket = null!;
    private PickupItem? _activeTool;
    private Node2D? _activeActor;
    private PickupCarrier? _activeCarrier;
    private bool _isProcessing;

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

    public PickupItem? ActiveTool =>
        GodotObject.IsInstanceValid(_activeTool) ? _activeTool : null;

    public override void _Ready()
    {
        _socket =
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "TimedItemProcessAction requires a valid pickup socket path."
            );
        _socket.ItemChanged += OnSocketItemChanged;
    }

    public override void _ExitTree()
    {
        ClearOwner();
        if (GodotObject.IsInstanceValid(_socket))
        {
            _socket.ItemChanged -= OnSocketItemChanged;
        }
    }

    public override bool IsAvailable(InteractionContext context)
    {
        PickupItem? item = _socket.Item;
        return item is not null
            && Recipe is not null
            && Recipe.Matches(item, context.Carrier.HeldItem);
    }

    public override bool Begin(InteractionContext context)
    {
        if (_isProcessing || !IsAvailable(context))
        {
            return false;
        }

        _activeTool = context.Carrier.HeldItem;
        _activeActor = context.Actor;
        _activeCarrier = context.Carrier;
        _activeActor.TreeExiting += OnOwnerTreeExiting;
        _activeCarrier.TreeExiting += OnOwnerTreeExiting;
        _elapsed = 0.0f;
        _isProcessing = true;
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
            !_isProcessing
            || !IsOwnedBy(context)
            || item is null
            || Recipe is null
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

        if (!Recipe.Apply(item))
        {
            return InteractionRunState.Failed;
        }

        _elapsed = 0.0f;
        EmitSignal(SignalName.ProgressChanged, 1.0f);
        _isProcessing = false;
        EmitSignal(SignalName.ProcessingCompleted, item);
        _activeTool = null;
        ClearOwner();
        return InteractionRunState.Completed;
    }

    public override void Cancel(InteractionContext context)
    {
        if (IsOwnedBy(context))
        {
            CancelProcessing();
        }
    }

    private void OnSocketItemChanged()
    {
        if (_isProcessing)
        {
            CancelProcessing();
        }
    }

    private void CancelProcessing()
    {
        if (!_isProcessing)
        {
            return;
        }

        _isProcessing = false;
        _elapsed = 0.0f;
        EmitSignal(SignalName.ProgressChanged, 0.0f);
        EmitSignal(SignalName.ProcessingCanceled);
        _activeTool = null;
        ClearOwner();
    }

    private bool IsOwnedBy(InteractionContext context)
    {
        return _activeActor == context.Actor
            && _activeCarrier == context.Carrier;
    }

    private void OnOwnerTreeExiting()
    {
        CancelProcessing();
    }

    private void ClearOwner()
    {
        if (GodotObject.IsInstanceValid(_activeActor))
        {
            _activeActor!.TreeExiting -= OnOwnerTreeExiting;
        }
        if (GodotObject.IsInstanceValid(_activeCarrier))
        {
            _activeCarrier!.TreeExiting -= OnOwnerTreeExiting;
        }

        _activeActor = null;
        _activeCarrier = null;
    }
}
