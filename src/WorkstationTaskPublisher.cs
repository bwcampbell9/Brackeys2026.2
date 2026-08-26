using System;
using Godot;

public partial class WorkstationTaskPublisher : Node2D
{
    public static readonly StringName PublisherGroup = "workstation_task_publishers";

    private TaskBroker? _broker;
    private PickupSocket _socket = null!;
    private InteractionTarget _interactionTarget = null!;
    private TimedItemProcessAction _processAction = null!;
    private int _generation;
    private long _currentTaskId;
    private long _executingTaskId;
    private bool _actionFinished;

    [Export]
    public NodePath SocketPath { get; set; } = new("../PickupSocket");

    [Export]
    public NodePath InteractionTargetPath { get; set; } =
        new("../InteractionTarget");

    [Export]
    public NodePath ProcessActionPath { get; set; } =
        new("../InteractionTarget/ProcessItemAction");

    [Export]
    public NpcTaskDefinition? FetchTask { get; set; }

    [Export]
    public NpcTaskDefinition? ActionTask { get; set; }

    [Export]
    public PickupItemDefinition? RequestedItem { get; set; }

    public Vector2 ApproachPosition => GlobalPosition;

    public long CurrentTaskId => _currentTaskId;

    public override void _Ready()
    {
        _socket =
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "WorkstationTaskPublisher requires a valid pickup socket."
            );
        _interactionTarget =
            GetNodeOrNull<InteractionTarget>(InteractionTargetPath)
            ?? throw new InvalidOperationException(
                "WorkstationTaskPublisher requires a valid interaction target."
            );
        _processAction =
            GetNodeOrNull<TimedItemProcessAction>(ProcessActionPath)
            ?? throw new InvalidOperationException(
                "WorkstationTaskPublisher requires a timed process action."
            );

        _socket.ItemChanged += OnSocketItemChanged;
        _processAction.ProcessingCompleted += OnProcessingCompleted;
        AddToGroup(PublisherGroup);
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_socket))
        {
            _socket.ItemChanged -= OnSocketItemChanged;
        }
        if (GodotObject.IsInstanceValid(_processAction))
        {
            _processAction.ProcessingCompleted -= OnProcessingCompleted;
        }
        if (_broker is not null && _currentTaskId != 0)
        {
            _broker.Cancel(_currentTaskId);
        }
    }

    public void Configure(TaskBroker broker)
    {
        if (_broker == broker)
        {
            return;
        }

        if (_broker is not null && _currentTaskId != 0)
        {
            _broker.Cancel(_currentTaskId);
            _currentTaskId = 0;
        }

        _broker = broker;
        ReconcileTask();
    }

    public bool TryDeliver(InteractionContext context, long taskId)
    {
        if (!CanExecute(taskId, NpcTaskKind.Fetch))
        {
            return false;
        }

        InteractionAction? transfer = _interactionTarget.FindAction(
            InteractionActionIds.Transfer,
            InteractionInputTrigger.Tap,
            context
        );
        if (transfer is null)
        {
            return false;
        }

        _executingTaskId = taskId;
        try
        {
            return transfer.Execute(context);
        }
        finally
        {
            _executingTaskId = 0;
        }
    }

    public bool TryBeginAction(InteractionContext context, long taskId)
    {
        return CanExecute(taskId, NpcTaskKind.Action)
            && _processAction.Begin(context);
    }

    public InteractionRunState UpdateAction(
        InteractionContext context,
        long taskId,
        double delta
    )
    {
        if (!CanExecute(taskId, NpcTaskKind.Action))
        {
            return InteractionRunState.Failed;
        }

        _executingTaskId = taskId;
        try
        {
            return _processAction.UpdateInteraction(context, delta);
        }
        finally
        {
            _executingTaskId = 0;
        }
    }

    public void CancelAction(InteractionContext context)
    {
        _processAction.Cancel(context);
    }

    private bool CanExecute(long taskId, NpcTaskKind kind)
    {
        return _broker is not null
            && _currentTaskId == taskId
            && _broker.GetStatus(taskId) == NpcTaskStatus.Claimed
            && (
                kind == NpcTaskKind.Fetch
                    ? _socket.Item is null
                    : _socket.Item is not null
            );
    }

    private void OnSocketItemChanged()
    {
        _generation++;
        _actionFinished = false;
        ReconcileTask();
    }

    private void OnProcessingCompleted(PickupItem item)
    {
        _actionFinished = true;
        ReconcileTask();
    }

    private void ReconcileTask()
    {
        if (_broker is null)
        {
            return;
        }

        long previousTaskId = _currentTaskId;
        _currentTaskId = 0;
        if (previousTaskId != 0 && previousTaskId != _executingTaskId)
        {
            _broker.Cancel(previousTaskId);
        }

        PickupItem? item = _socket.Item;
        if (item is null)
        {
            if (FetchTask is null || RequestedItem is null)
            {
                return;
            }

            _currentTaskId = _broker.Publish(
                FetchTask,
                this,
                _generation,
                RequestedItem,
                null
            );
            return;
        }

        ProcessingRecipe? recipe = _processAction.Recipe;
        if (
            ActionTask is null
            || _actionFinished
            || recipe is null
            || !recipe.Matches(item)
        )
        {
            return;
        }

        _currentTaskId = _broker.Publish(
            ActionTask,
            this,
            _generation,
            null,
            recipe.RequiredTool
        );
    }
}
