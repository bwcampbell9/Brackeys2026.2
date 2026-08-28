using System;
using Godot;
using Godot.Collections;

public enum WorkstationTaskRequestMode
{
	Automatic,
	PlayerStarted,
	AutomaticAction,
}

public partial class WorkstationTaskPublisher : Node2D
{
	public static readonly StringName PublisherGroup = "workstation_task_publishers";

	private TaskBroker? _broker;
	private PickupSocket _socket = null!;
	private InteractionTarget _interactionTarget = null!;
	private TimedItemProcessAction? _processAction;
	private Node2D _requestIndicator = null!;
	private Sprite2D _requestIndicatorIcon = null!;
	private Node2D? _configuredItemIndicator;
	private Sprite2D? _configuredItemIcon;
	private WorkstationRequestWheel? _requestWheel;
	private Node2D? _consumerVisual;
	private Tween? _consumptionTween;
	private Vector2 _consumerRestPosition;
	private Vector2 _consumerRestScale;
	private int _generation;
	private long _currentTaskId;
	private long _executingTaskId;
	private bool _actionFinished;
	private bool _isConsuming;
	private bool _isConfiguring;
	private PickupItemDefinition? _currentRequestedItem;
	private PickupItemDefinition? _requestedItem;
	private WorkstationTaskRequestMode _requestMode;

	[Export]
	public NodePath SocketPath { get; set; } = new("../PickupSocket");

	[Export]
	public NodePath InteractionTargetPath { get; set; } =
		new("../InteractionTarget");

	[Export]
	public NodePath ProcessActionPath { get; set; } =
		new("../InteractionTarget/ProcessItemAction");

	[Export]
	public NodePath RequestIndicatorPath { get; set; } =
		new("../TaskRequestIndicator");

	[Export]
	public NodePath RequestIndicatorIconPath { get; set; } =
		new("../TaskRequestIndicator/Icon");

	[Export]
	public NodePath ConfiguredItemIndicatorPath { get; set; } =
		new("../ConfiguredItemIndicator");

	[Export]
	public NodePath ConfiguredItemIconPath { get; set; } =
		new("../ConfiguredItemIndicator/Icon");

	[Export]
	public NodePath RequestWheelPath { get; set; } =
		new("../RequestWheelLayer/RequestWheel");

	[Export]
	public WorkstationTaskRequestMode RequestMode
	{
		get => _requestMode;
		set
		{
			if (_requestMode == value)
			{
				return;
			}

			_requestMode = value;
			if (IsNodeReady())
			{
				ReconcileTask();
			}
		}
	}

	[Export]
	public NpcTaskDefinition? FetchTask { get; set; }

	[Export]
	public NpcTaskDefinition? ActionTask { get; set; }

	[Export]
	public PickupItemDefinition? RequestedItem
	{
		get => _requestedItem;
		set => _requestedItem = value;
	}

	[Export]
	public Array<PickupItemDefinition> AvailableItems { get; set; } = new();

	[Export]
	public bool ConsumeDeliveredItem { get; set; }

	[Export]
	public NodePath ConsumerVisualPath { get; set; } = new("../Sprite2D");

	[Export(PropertyHint.Range, "0.1,3,0.05,or_greater")]
	public float ConsumptionDuration { get; set; } = 0.6f;

	public Vector2 ApproachPosition => GlobalPosition;

	public long CurrentTaskId => _currentTaskId;

	public PickupItemDefinition? CurrentRequestedItem => _currentRequestedItem;

	public bool IsConsuming => _isConsuming;

	public bool IsConfiguring => _isConfiguring;

	public bool CanConfigure =>
		!_isConsuming && _socket.Item is null && AvailableItems.Count > 0;

	public bool CanPublishNextTask =>
		(
			RequestMode == WorkstationTaskRequestMode.PlayerStarted
			|| (
				RequestMode == WorkstationTaskRequestMode.AutomaticAction
				&& _socket.Item is null
			)
		)
		&& _broker is not null
		&& _currentTaskId == 0
		&& TryGetPendingTask(out _, out _, out _);

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
		_processAction = GetNodeOrNull<TimedItemProcessAction>(
			ProcessActionPath
		);
		if (ActionTask is not null && _processAction is null)
		{
			throw new InvalidOperationException(
                "A workstation with an action task requires a timed process action."
			);
		}
		_requestIndicator =
			GetNodeOrNull<Node2D>(RequestIndicatorPath)
			?? throw new InvalidOperationException(
                "WorkstationTaskPublisher requires a request indicator."
			);
		_requestIndicatorIcon =
			GetNodeOrNull<Sprite2D>(RequestIndicatorIconPath)
			?? throw new InvalidOperationException(
                "WorkstationTaskPublisher requires a request indicator icon."
			);
		_configuredItemIndicator = GetNodeOrNull<Node2D>(
			ConfiguredItemIndicatorPath
		);
		_configuredItemIcon = GetNodeOrNull<Sprite2D>(ConfiguredItemIconPath);
		_requestWheel = GetNodeOrNull<WorkstationRequestWheel>(
			RequestWheelPath
		);

		if (ConsumeDeliveredItem)
		{
			_consumerVisual =
				GetNodeOrNull<Node2D>(ConsumerVisualPath)
				?? throw new InvalidOperationException(
                    "A consuming workstation requires a consumer visual."
				);
			_consumerRestPosition = _consumerVisual.Position;
			_consumerRestScale = _consumerVisual.Scale;
		}

		_socket.ItemChanged += OnSocketItemChanged;
		if (_processAction is not null)
		{
			_processAction.ProcessingCompleted += OnProcessingCompleted;
		}
		AddToGroup(PublisherGroup);
		ClearRequestIndicator();
		UpdateConfiguredItemIndicator();
	}

	public override void _ExitTree()
	{
		if (GodotObject.IsInstanceValid(_socket))
		{
			_socket.ItemChanged -= OnSocketItemChanged;
		}
		if (
			_processAction is not null
			&& GodotObject.IsInstanceValid(_processAction)
		)
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

	public bool BeginConfiguration()
	{
		if (!CanConfigure || _requestWheel is null)
		{
			return false;
		}

		_isConfiguring = true;
		_requestWheel.Open(
			AvailableItems,
			RequestedItem,
			GetParent<Node2D>().GetGlobalTransformWithCanvas().Origin
		);
		return true;
	}

	public void CancelConfiguration()
	{
		if (!_isConfiguring)
		{
			return;
		}

		_isConfiguring = false;
		_requestWheel?.Close();
	}

	public void CompleteConfiguration()
	{
		if (!_isConfiguring)
		{
			return;
		}

		PickupItemDefinition? selectedItem = _requestWheel?.SelectedItem;
		_isConfiguring = false;
		_requestWheel?.Close();
		if (selectedItem is null || RequestedItem?.Id == selectedItem.Id)
		{
			return;
		}

		bool hadTask = _currentTaskId != 0;
		RequestedItem = selectedItem;
		_generation++;
		CancelCurrentTask();
		UpdateConfiguredItemIndicator();
		if (hadTask)
		{
			PublishPendingTask();
		}
	}

	public bool TryPublishNextTask()
	{
		return CanPublishNextTask && PublishPendingTask();
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
		return _processAction is not null
			&& CanExecute(taskId, NpcTaskKind.Action)
			&& _processAction.Begin(context);
	}

	public InteractionRunState UpdateAction(
		InteractionContext context,
		long taskId,
		double delta
	)
	{
		if (
			_processAction is null
			|| !CanExecute(taskId, NpcTaskKind.Action)
		)
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
		_processAction?.Cancel(context);
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
		_socket.SetNpcSourceEnabled(false);
		if (TryBeginConsumption())
		{
			return;
		}
		ReconcileTask();
	}

	private void OnProcessingCompleted(PickupItem item)
	{
		_actionFinished = true;
		_socket.SetNpcSourceEnabled(true);
		ReconcileTask();
	}

	private void ReconcileTask()
	{
		if (_broker is null || _isConsuming)
		{
			return;
		}

		long previousTaskId = _currentTaskId;
		_currentTaskId = 0;
		ClearRequestIndicator();
		if (
			previousTaskId != 0
			&& (
				previousTaskId != _executingTaskId
				|| _socket.Item is null
			)
		)
		{
			_broker.Cancel(previousTaskId);
		}

		if (
			RequestMode == WorkstationTaskRequestMode.Automatic
			|| (
				RequestMode == WorkstationTaskRequestMode.AutomaticAction
				&& _socket.Item is not null
			)
		)
		{
			PublishPendingTask();
		}
	}

	private void CancelCurrentTask()
	{
		if (_broker is not null && _currentTaskId != 0)
		{
			_broker.Cancel(_currentTaskId);
		}

		_currentTaskId = 0;
		ClearRequestIndicator();
	}

	private bool PublishPendingTask()
	{
		if (
			_broker is null
			|| _currentTaskId != 0
			|| !TryGetPendingTask(
				out NpcTaskDefinition? task,
				out PickupItemDefinition? requestedItem,
				out PickupItemDefinition? requiredTool
			)
			|| task is null
		)
		{
			return false;
		}

		PickupItemDefinition? currentRequest = requestedItem ?? requiredTool;
		if (currentRequest is null)
		{
			return false;
		}

		_currentTaskId = _broker.Publish(
			task,
			this,
			_generation,
			requestedItem,
			requiredTool
		);
		ShowRequestIndicator(currentRequest);
		return true;
	}

	private bool TryGetPendingTask(
		out NpcTaskDefinition? task,
		out PickupItemDefinition? requestedItem,
		out PickupItemDefinition? requiredTool
	)
	{
		task = null;
		requestedItem = null;
		requiredTool = null;

		PickupItem? item = _socket.Item;
		if (item is null)
		{
			if (FetchTask is null || RequestedItem is null)
			{
				return false;
			}

			task = FetchTask;
			requestedItem = RequestedItem;
			return true;
		}

		ProcessingRecipe? recipe = _processAction?.Recipe;
		if (
			ActionTask is null
			|| _actionFinished
			|| recipe is null
			|| !recipe.Matches(item)
		)
		{
			return false;
		}

		task = ActionTask;
		requiredTool = recipe.RequiredTool;
		return requiredTool is not null;
	}

	private void ShowRequestIndicator(PickupItemDefinition item)
	{
		_currentRequestedItem = item;
		_requestIndicatorIcon.Texture = item.Texture;
		_requestIndicatorIcon.Modulate = item.Modulate;
		_requestIndicatorIcon.Scale = item.VisualScale * 0.65f;
		_requestIndicator.Visible = true;
	}

	private void UpdateConfiguredItemIndicator()
	{
		if (
			!GodotObject.IsInstanceValid(_configuredItemIndicator)
			|| !GodotObject.IsInstanceValid(_configuredItemIcon)
		)
		{
			return;
		}

		if (RequestedItem is null)
		{
			_configuredItemIndicator.Visible = false;
			return;
		}

		_configuredItemIcon.Texture = RequestedItem.Texture;
		_configuredItemIcon.Modulate = RequestedItem.Modulate * new Color(0.4f, 0.7f, 1.0f, 1.0f);
		_configuredItemIcon.Scale = RequestedItem.VisualScale;
		_configuredItemIndicator.Visible = true;
	}


	private void ClearRequestIndicator()
	{
		_currentRequestedItem = null;
		if (GodotObject.IsInstanceValid(_requestIndicator))
		{
			_requestIndicator.Visible = false;
		}
		if (GodotObject.IsInstanceValid(_requestIndicatorIcon))
		{
			_requestIndicatorIcon.Texture = null;
		}
	}

	private bool TryBeginConsumption()
	{
		PickupItem? item = _socket.Item;
		if (
			!ConsumeDeliveredItem
			|| _isConsuming
			|| item?.Definition is null
			|| RequestedItem is null
			|| item.Definition.Id != RequestedItem.Id
			|| !_socket.TryLock(item)
		)
		{
			return false;
		}

		long previousTaskId = _currentTaskId;
		_currentTaskId = 0;
		ClearRequestIndicator();
		if (
			_broker is not null
			&& previousTaskId != 0
			&& previousTaskId != _executingTaskId
		)
		{
			_broker.Cancel(previousTaskId);
		}

		_isConsuming = true;
		PlayConsumption(item);
		return true;
	}

	private void PlayConsumption(PickupItem item)
	{
		Node2D visual =
			_consumerVisual
			?? throw new InvalidOperationException(
                "A consuming workstation requires a consumer visual."
			);
		float phaseDuration = ConsumptionDuration * 0.5f;
		Vector2 squashedScale = new(
			_consumerRestScale.X * 1.15f,
			_consumerRestScale.Y * 0.82f
		);
		Vector2 bobPosition = _consumerRestPosition + Vector2.Up * 6.0f;

		_consumptionTween?.Kill();
		Tween foodTween = item.StartMotionTween();
		foodTween
			.TweenProperty(
				item,
				new NodePath("scale"),
				Vector2.Zero,
				ConsumptionDuration
			)
			.SetTrans(Tween.TransitionType.Quad)
			.SetEase(Tween.EaseType.In);

		Tween scaleTween = CreateTween();
		_consumptionTween = scaleTween;
		scaleTween
			.TweenProperty(
				visual,
				new NodePath("scale"),
				squashedScale,
				phaseDuration
			)
			.SetTrans(Tween.TransitionType.Quad)
			.SetEase(Tween.EaseType.In);
		scaleTween
			.TweenProperty(
				visual,
				new NodePath("scale"),
				_consumerRestScale,
				phaseDuration
			)
			.SetTrans(Tween.TransitionType.Back)
			.SetEase(Tween.EaseType.Out);
		scaleTween.TweenCallback(
			Callable.From(() => FinishConsumption(item))
		);

		Tween bobTween = CreateTween();
		bobTween
			.TweenProperty(
				visual,
				new NodePath("position"),
				bobPosition,
				phaseDuration
			)
			.SetTrans(Tween.TransitionType.Quad)
			.SetEase(Tween.EaseType.In);
		bobTween
			.TweenProperty(
				visual,
				new NodePath("position"),
				_consumerRestPosition,
				phaseDuration
			)
			.SetTrans(Tween.TransitionType.Back)
			.SetEase(Tween.EaseType.Out);
	}

	private void FinishConsumption(PickupItem item)
	{
		if (
			_consumerVisual is not null
			&& GodotObject.IsInstanceValid(_consumerVisual)
		)
		{
			_consumerVisual.Position = _consumerRestPosition;
			_consumerVisual.Scale = _consumerRestScale;
		}

		if (!_socket.TryDiscard(item))
		{
			_isConsuming = false;
			_consumptionTween = null;
			GD.PushError(
                "A consuming workstation lost its locked delivered item."
			);
			return;
		}

		_isConsuming = false;
		_consumptionTween = null;
		ReconcileTask();
	}
}
