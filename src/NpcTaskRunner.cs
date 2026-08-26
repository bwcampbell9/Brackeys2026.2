using System;
using System.Collections.Generic;
using Godot;
using Godot.Collections;

public enum NpcWorkerState
{
    Idle,
    NavigatingToSource,
    RetryDelay,
    NavigatingToDestination,
    Working,
    ReturningItem,
    Wandering,
}

public partial class NpcTaskRunner : Node
{
    public static readonly StringName RunnerGroup = "npc_task_runners";

    private readonly HashSet<StringName> _capabilityTags = new();
    private CharacterBody2D _actor = null!;
    private NpcMotor _motor = null!;
    private PickupCarrier _carrier = null!;
    private RandomNumberGenerator _random = null!;
    private TaskBroker? _broker;
    private ItemSourceCatalog? _catalog;
    private NpcTaskRequest? _task;
    private IItemSource? _source;
    private IItemSource? _returnSource;
    private PickupItemDefinition? _selectedDefinition;
    private NpcTaskFailureMode? _selectedFailureMode;
    private float _retryRemaining;
    private float _wanderWait;

    [Signal]
    public delegate void StateChangedEventHandler(int state);

    [Export]
    public NodePath MotorPath { get; set; } = new("../NpcMotor");

    [Export]
    public NodePath CarrierPath { get; set; } = new("../PickupCarrier");

    [Export]
    public Array<StringName> CapabilityTags { get; set; } = new()
    {
        "kitchen",
    };

    [Export]
    public NpcPersonality? Personality { get; set; }

    [Export(PropertyHint.Range, "0.1,10,0.1,or_greater")]
    public float RetryDelay { get; set; } = 1.0f;

    [Export(PropertyHint.Range, "0.1,10,0.1,or_greater")]
    public float WanderDelay { get; set; } = 1.5f;

    [Export]
    public Rect2 WanderBounds { get; set; } =
        new(96.0f, 96.0f, 768.0f, 320.0f);

    [Export]
    public long RandomSeed { get; set; }

    public NpcWorkerState State { get; private set; }

    public StringName SelectedItemId =>
        _selectedDefinition?.Id ?? new StringName();

    public long CurrentTaskId => _task?.Id ?? 0;

    public int SelectedFailureMode =>
        _selectedFailureMode.HasValue
            ? (int)_selectedFailureMode.Value
            : -1;

    public override void _Ready()
    {
        _actor =
            GetParentOrNull<CharacterBody2D>()
            ?? throw new InvalidOperationException(
                "NpcTaskRunner must be a child of CharacterBody2D."
            );
        _motor =
            GetNodeOrNull<NpcMotor>(MotorPath)
            ?? throw new InvalidOperationException(
                "NpcTaskRunner requires an NpcMotor."
            );
        _carrier =
            GetNodeOrNull<PickupCarrier>(CarrierPath)
            ?? throw new InvalidOperationException(
                "NpcTaskRunner requires a PickupCarrier."
            );
        _random = new RandomNumberGenerator();
        if (RandomSeed == 0)
        {
            _random.Randomize();
        }
        else
        {
            _random.Seed = (ulong)RandomSeed;
        }

        foreach (StringName capabilityTag in CapabilityTags)
        {
            _capabilityTags.Add(capabilityTag);
        }

        _wanderWait = WanderDelay;
        AddToGroup(RunnerGroup);
    }

    public override void _ExitTree()
    {
        if (_broker is not null)
        {
            _broker.TasksChanged -= OnTasksChanged;
            if (_task is not null)
            {
                _broker.Release(_task.Id, this);
            }
        }
        _catalog?.Release(_source, this);
    }

    public void Configure(TaskBroker broker, ItemSourceCatalog catalog)
    {
        if (_broker == broker && _catalog == catalog)
        {
            return;
        }

        if (_broker is not null)
        {
            _broker.TasksChanged -= OnTasksChanged;
            if (_task is not null)
            {
                _broker.Release(_task.Id, this);
            }
        }
        _catalog?.Release(_source, this);

        _broker = broker;
        _catalog = catalog;
        _task = null;
        _source = null;
        _returnSource = null;
        _selectedDefinition = null;
        _selectedFailureMode = null;
        _broker.TasksChanged += OnTasksChanged;
        _motor.Stop();
        SetState(NpcWorkerState.Idle);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_broker is null || _catalog is null)
        {
            return;
        }

        if (
            _task is not null
            && State
                is not NpcWorkerState.ReturningItem
                    and not NpcWorkerState.Idle
                    and not NpcWorkerState.Wandering
            && (
                _task.Status != NpcTaskStatus.Claimed
                || _task.Claimant != this
            )
        )
        {
            HandleLostTask();
            return;
        }

        if (
            _task is not null
            && _carrier.HeldItem is null
            && State
                is NpcWorkerState.NavigatingToDestination
                    or NpcWorkerState.Working
        )
        {
            BeginRetry();
            return;
        }

        switch (State)
        {
            case NpcWorkerState.Idle:
            case NpcWorkerState.Wandering:
                UpdateIdle((float)delta);
                break;
            case NpcWorkerState.NavigatingToSource:
                UpdateSourceNavigation();
                break;
            case NpcWorkerState.RetryDelay:
                UpdateRetry((float)delta);
                break;
            case NpcWorkerState.NavigatingToDestination:
                UpdateDestinationNavigation();
                break;
            case NpcWorkerState.Working:
                UpdateWork(delta);
                break;
            case NpcWorkerState.ReturningItem:
                UpdateReturn();
                break;
        }
    }

    private void UpdateIdle(float delta)
    {
        if (_carrier.HeldItem is not null)
        {
            _carrier.Throw();
        }

        if (TryClaimWork())
        {
            return;
        }

        if (!_motor.IsAtTarget)
        {
            SetState(NpcWorkerState.Wandering);
            return;
        }

        _wanderWait -= delta;
        if (_wanderWait > 0.0f)
        {
            SetState(NpcWorkerState.Idle);
            return;
        }

        _wanderWait = WanderDelay;
        Vector2 wanderTarget = new(
            _random.RandfRange(WanderBounds.Position.X, WanderBounds.End.X),
            _random.RandfRange(WanderBounds.Position.Y, WanderBounds.End.Y)
        );
        _motor.SetTarget(wanderTarget);
        SetState(NpcWorkerState.Wandering);
    }

    private bool TryClaimWork()
    {
        if (
            _broker is null
            || _catalog is null
            || !_broker.TryClaim(
                this,
                _capabilityTags,
                _actor.GlobalPosition,
                IsTaskReady,
                out NpcTaskRequest? task
            )
            || task is null
        )
        {
            return false;
        }

        _task = task;
        _returnSource = null;
        if (task.Definition.Kind == NpcTaskKind.Fetch)
        {
            PickupItemDefinition? requestedItem = task.RequestedItem;
            if (requestedItem is null)
            {
                _broker.Cancel(task.Id);
                EnterIdle();
                return true;
            }

            _selectedDefinition = RollFetchDefinition(task, requestedItem);
        }
        else
        {
            _selectedFailureMode = null;
            _selectedDefinition = task.RequiredTool;
            if (_selectedDefinition is null)
            {
                NavigateToDestination();
                return true;
            }
        }

        TrySelectSourceOrWait();
        return true;
    }

    private PickupItemDefinition RollFetchDefinition(
        NpcTaskRequest task,
        PickupItemDefinition requestedItem
    )
    {
        if (_catalog is null)
        {
            return requestedItem;
        }

        List<PickupItemDefinition> alternatives =
            _catalog.GetAvailableDefinitionsExcluding(requestedItem, this);
        _selectedFailureMode = NpcFailurePolicy.Select(
            task.Definition,
            Personality,
            _random,
            mode =>
                mode == NpcTaskFailureMode.WrongFetchedItem
                && alternatives.Count > 0
        );
        return _selectedFailureMode == NpcTaskFailureMode.WrongFetchedItem
            ? alternatives[_random.RandiRange(0, alternatives.Count - 1)]
            : requestedItem;
    }

    private bool IsTaskReady(NpcTaskRequest task)
    {
        if (_catalog is null)
        {
            return false;
        }

        PickupItemDefinition? requiredItem =
            task.Definition.Kind == NpcTaskKind.Fetch
                ? task.RequestedItem
                : task.RequiredTool;
        return requiredItem is null
            || _catalog.HasAvailableSource(requiredItem, this);
    }

    private void TrySelectSourceOrWait()
    {
        if (
            _catalog is null
            || _selectedDefinition is null
            || !_catalog.TryReserveSource(
                _selectedDefinition,
                this,
                _random,
                out IItemSource? source
            )
            || source is null
        )
        {
            BeginRetry();
            return;
        }

        _source = source;
        _motor.SetTarget(source.ApproachPosition);
        SetState(NpcWorkerState.NavigatingToSource);
    }

    private void UpdateSourceNavigation()
    {
        if (
            _source is null
            || !GodotObject.IsInstanceValid(_source.SourceNode)
            || !_source.IsSourceAvailable
        )
        {
            BeginRetry();
            return;
        }

        if (
            _motor.TargetPosition.DistanceSquaredTo(_source.ApproachPosition)
            > 576.0f
        )
        {
            _motor.SetTarget(_source.ApproachPosition);
        }

        if (!_motor.IsAtTarget)
        {
            return;
        }

        InteractionContext context = new(_actor, _carrier);
        IItemSource acquiredSource = _source;
        if (!acquiredSource.TryAcquire(context))
        {
            BeginRetry();
            return;
        }

        _catalog?.Release(acquiredSource, this);
        _source = null;
        if (_task?.Definition.Kind == NpcTaskKind.Action)
        {
            _returnSource = acquiredSource;
        }
        NavigateToDestination();
    }

    private void BeginRetry()
    {
        if (_task is not null && State == NpcWorkerState.Working)
        {
            _task.Destination.CancelAction(new InteractionContext(_actor, _carrier));
        }

        _catalog?.Release(_source, this);
        _source = null;
        if (_task is not null)
        {
            _broker?.Release(_task.Id, this);
            _task = null;
        }
        _selectedDefinition = null;
        _selectedFailureMode = null;
        _motor.Stop();
        _retryRemaining = RetryDelay;
        SetState(NpcWorkerState.RetryDelay);
    }

    private void UpdateRetry(float delta)
    {
        _retryRemaining -= delta;
        if (_retryRemaining <= 0.0f)
        {
            EnterIdle();
        }
    }

    private void NavigateToDestination()
    {
        if (_task is null)
        {
            HandleLostTask();
            return;
        }

        _motor.SetTarget(_task.Destination.ApproachPosition);
        SetState(NpcWorkerState.NavigatingToDestination);
    }

    private void UpdateDestinationNavigation()
    {
        if (_task is null || !_motor.IsAtTarget)
        {
            return;
        }

        InteractionContext context = new(_actor, _carrier);
        if (_task.Definition.Kind == NpcTaskKind.Fetch)
        {
            if (!_task.Destination.TryDeliver(context, _task.Id))
            {
                ReleaseTaskAndCleanup();
                return;
            }

            _broker?.Complete(_task.Id, this);
            EnterIdle();
            return;
        }

        if (!_task.Destination.TryBeginAction(context, _task.Id))
        {
            ReleaseTaskAndCleanup();
            return;
        }

        SetState(NpcWorkerState.Working);
    }

    private void UpdateWork(double delta)
    {
        if (_task is null)
        {
            HandleLostTask();
            return;
        }

        InteractionContext context = new(_actor, _carrier);
        InteractionRunState runState = _task.Destination.UpdateAction(
            context,
            _task.Id,
            delta
        );
        if (runState == InteractionRunState.Running)
        {
            return;
        }

        if (runState == InteractionRunState.Failed)
        {
            _task.Destination.CancelAction(context);
            _broker?.Release(_task.Id, this);
        }
        else
        {
            _broker?.Complete(_task.Id, this);
        }

        _task = null;
        StartReturningItem();
    }

    private void ReleaseTaskAndCleanup()
    {
        if (_task is not null)
        {
            _broker?.Release(_task.Id, this);
            _task = null;
        }
        StartReturningItem();
    }

    private void StartReturningItem()
    {
        if (_carrier.HeldItem is null)
        {
            EnterIdle();
            return;
        }

        if (
            _returnSource is null
            || !GodotObject.IsInstanceValid(_returnSource.SourceNode)
            || !_returnSource.CanReturnItem
        )
        {
            _carrier.Throw();
            EnterIdle();
            return;
        }

        _motor.SetTarget(_returnSource.ApproachPosition);
        SetState(NpcWorkerState.ReturningItem);
    }

    private void UpdateReturn()
    {
        if (_returnSource is null || !_motor.IsAtTarget)
        {
            return;
        }

        InteractionContext context = new(_actor, _carrier);
        if (_returnSource.TryReturn(context))
        {
            _returnSource = null;
            EnterIdle();
            return;
        }

        _motor.Stop();
        _retryRemaining = RetryDelay;
    }

    private void HandleLostTask()
    {
        _catalog?.Release(_source, this);
        _source = null;
        _task = null;
        _motor.Stop();
        StartReturningItem();
    }

    private void EnterIdle()
    {
        _task = null;
        _source = null;
        _selectedDefinition = null;
        _selectedFailureMode = null;
        _wanderWait = WanderDelay;
        SetState(NpcWorkerState.Idle);
    }

    private void OnTasksChanged()
    {
        if (State is NpcWorkerState.Idle or NpcWorkerState.Wandering)
        {
            _motor.Stop();
            SetState(NpcWorkerState.Idle);
        }
    }

    private void SetState(NpcWorkerState state)
    {
        if (State == state)
        {
            return;
        }

        State = state;
        EmitSignal(SignalName.StateChanged, (int)state);
    }
}
