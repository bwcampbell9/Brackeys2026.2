using System;
using Godot;
using Godot.Collections;

public enum WorkstationTaskRequestMode
{
	Automatic,
	PlayerStarted,
	AutomaticAction,
}

public enum CustomerOrderOutcome
{
	Correct,
	Wrong,
	Missed,
}

public partial class WorkstationTaskPublisher : Node2D
{
	public static readonly StringName PublisherGroup = "workstation_task_publishers";
	private static readonly StringName RequestIndicatorOpenAnimation = new("open");

	private TaskBroker? _broker;
	private PickupSocket _socket = null!;
	private InteractionTarget _interactionTarget = null!;
	private TimedItemProcessAction? _processAction;
	private OvenCookingController? _cookingController;
	private Node2D _requestIndicator = null!;
	private AnimatedSprite2D _requestIndicatorAnimation = null!;
	private Sprite2D _requestIndicatorIcon = null!;
	private Sprite2D _requestIndicatorSecondaryIcon = null!;
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
	private CookingRecipe? _selectedCookingRecipe;
	private WorkstationTaskRequestMode _requestMode;
	private Sprite2D? _orderTimerBar;
	private float _orderTimeRemaining;
	private float _orderCooldownRemaining;

	public event Action<CustomerOrderOutcome>? CustomerOrderResolved;

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
	public NodePath RequestIndicatorAnimationPath { get; set; } =
		new("../TaskRequestIndicator/Background");

	[Export]
	public NodePath RequestIndicatorIconPath { get; set; } =
		new("../TaskRequestIndicator/Icon");

	[Export]
	public NodePath RequestIndicatorSecondaryIconPath { get; set; } =
		new("../TaskRequestIndicator/SecondaryIcon");

	[Export(PropertyHint.Range, "1,60,1")]
	public float RequestIndicatorOpenFramesPerSecond { get; set; } = 24.0f;

	[Export]
	public NodePath RequestWheelPath { get; set; } =
		new("../RequestWheelLayer/RequestWheel");

	[Export]
	public NodePath CookingControllerPath { get; set; } = new();

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

	[Export]
	public NodePath OrderTimerBarPath { get; set; } =
		new("../TaskRequestIndicator/TimerBar");

	[Export(PropertyHint.Range, "1,300,1,or_greater")]
	public float OrderDurationSeconds { get; set; } = 30.0f;

	[Export(PropertyHint.Range, "0,60,0.5,or_greater")]
	public float OrderCooldownSeconds { get; set; } = 5.0f;

	public Vector2 ApproachPosition => GlobalPosition;

	public long CurrentTaskId => _currentTaskId;

	public PickupItemDefinition? CurrentRequestedItem => _currentRequestedItem;

	public bool IsConsuming => _isConsuming;

	public bool IsConfiguring => _isConfiguring;

	public bool IsAcceptingCustomerDelivery =>
		ConsumeDeliveredItem
		&& !_isConsuming
		&& _currentTaskId != 0
		&& _orderTimeRemaining > 0.0f;

	public bool CanConfigure =>
		!_isConsuming
		&& (
			_cookingController is not null
				? !_cookingController.HasAnyItem
					&& _cookingController.Recipes.Count > 0
				: _socket.Item is null && AvailableItems.Count > 0
		);

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
		_requestIndicatorAnimation =
			GetNodeOrNull<AnimatedSprite2D>(RequestIndicatorAnimationPath)
			?? throw new InvalidOperationException(
                "WorkstationTaskPublisher requires an animated request indicator background."
			);
		_requestIndicatorIcon =
			GetNodeOrNull<Sprite2D>(RequestIndicatorIconPath)
			?? throw new InvalidOperationException(
                "WorkstationTaskPublisher requires a request indicator icon."
			);
		_requestIndicatorSecondaryIcon =
			GetNodeOrNull<Sprite2D>(RequestIndicatorSecondaryIconPath)
			?? throw new InvalidOperationException(
                "WorkstationTaskPublisher requires a secondary request indicator icon."
			);
		_requestWheel = GetNodeOrNull<WorkstationRequestWheel>(
			RequestWheelPath
		);
		if (!CookingControllerPath.IsEmpty)
		{
			_cookingController =
				GetNodeOrNull<OvenCookingController>(CookingControllerPath)
				?? throw new InvalidOperationException(
					"WorkstationTaskPublisher requires a valid cooking controller."
				);
			_selectedCookingRecipe =
				_cookingController.SelectedCookingRecipe;
			if (_selectedCookingRecipe?.Ingredients.Count > 0)
			{
				RequestedItem = _selectedCookingRecipe.Ingredients[0];
			}
		}

		if (ConsumeDeliveredItem)
		{
			_consumerVisual =
				GetNodeOrNull<Node2D>(ConsumerVisualPath)
				?? throw new InvalidOperationException(
                    "A consuming workstation requires a consumer visual."
				);
			_consumerRestPosition = _consumerVisual.Position;
			_consumerRestScale = _consumerVisual.Scale;
			_orderTimerBar =
				GetNodeOrNull<Sprite2D>(OrderTimerBarPath)
				?? throw new InvalidOperationException(
                    "A consuming workstation requires an order timer bar."
				);
			_orderTimerBar.Visible = false;
		}

		if (_cookingController is not null)
		{
			_cookingController.CookingStateChanged += OnCookingStateChanged;
		}
		else
		{
			_socket.ItemChanged += OnSocketItemChanged;
		}
		if (_processAction is not null)
		{
			_processAction.ProcessingCompleted += OnProcessingCompleted;
		}
		AddToGroup(PublisherGroup);
		ClearRequestIndicator();
	}

	public override void _Process(double delta)
	{
		if (!ConsumeDeliveredItem)
		{
			return;
		}

		if (_orderCooldownRemaining > 0.0f)
		{
			_orderCooldownRemaining = Mathf.Max(
				0.0f,
				_orderCooldownRemaining - (float)delta
			);
			if (
				Mathf.IsZeroApprox(_orderCooldownRemaining)
				&& !_isConsuming
			)
			{
				ReconcileTask();
			}
			return;
		}

		if (_isConsuming)
		{
			return;
		}

		if (_currentTaskId == 0 || _orderTimeRemaining <= 0.0f)
		{
			return;
		}

		_orderTimeRemaining = Mathf.Max(
			0.0f,
			_orderTimeRemaining - (float)delta
		);
		UpdateOrderTimerBar();
		if (Mathf.IsZeroApprox(_orderTimeRemaining))
		{
			ResolveMissedOrder();
		}
	}

	public override void _ExitTree()
	{
		if (
			_cookingController is not null
			&& GodotObject.IsInstanceValid(_cookingController)
		)
		{
			_cookingController.CookingStateChanged -= OnCookingStateChanged;
		}
		else if (GodotObject.IsInstanceValid(_socket))
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
		if (_isConfiguring || !CanConfigure || _requestWheel is null)
		{
			return false;
		}

		_isConfiguring = true;
		Vector2 center =
			GetParent<Node2D>().GetGlobalTransformWithCanvas().Origin;
		if (_cookingController is not null)
		{
			_requestWheel.OpenRecipes(
				_cookingController.Recipes,
				_selectedCookingRecipe,
				center
			);
		}
		else
		{
			_requestWheel.Open(AvailableItems, RequestedItem, center);
		}
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
		CookingRecipe? selectedRecipe = _requestWheel?.SelectedRecipe;
		_isConfiguring = false;
		_requestWheel?.Close();
		if (selectedItem is null)
		{
			return;
		}

		if (_cookingController is not null)
		{
			if (
				selectedRecipe is null
				|| selectedRecipe.Ingredients.Count == 0
				|| (
					_selectedCookingRecipe?.Output?.Id
						!= selectedRecipe.Output?.Id
					&& !_cookingController.TrySelectRecipe(selectedRecipe)
				)
			)
			{
				return;
			}

			if (
				_selectedCookingRecipe?.Output?.Id
				!= selectedRecipe.Output?.Id
			)
			{
				_selectedCookingRecipe = selectedRecipe;
				RequestedItem = selectedRecipe.Ingredients[0];
				_generation++;
				CancelCurrentTask();
			}
			PublishPendingTask();
			return;
		}

		if (RequestedItem?.Id != selectedItem.Id)
		{
			RequestedItem = selectedItem;
			_generation++;
			CancelCurrentTask();
		}

		PublishPendingTask();
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
					? _cookingController is not null
						? _cookingController.GetFirstMissingIngredient()
							is not null
						: _socket.Item is null
					: _socket.Item is not null
			);
	}

	private void OnCookingStateChanged()
	{
		OnSocketItemChanged();
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
			|| (
				_cookingController is not null
				&& _cookingController.HasAnyItem
				&& _cookingController.GetFirstMissingIngredient() is not null
			)
		)
		{
			PublishPendingTask();
		}
	}

	public void ClearCurrentTask()
	{
		if (_broker is not null && _currentTaskId != 0)
		{
			_broker.Cancel(_currentTaskId);
		}

		_currentTaskId = 0;
		_currentRequestedItem = null;
		ClearRequestIndicator();
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
			|| _orderCooldownRemaining > 0.0f
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
		if (ConsumeDeliveredItem)
		{
			_orderTimeRemaining = Mathf.Max(0.01f, OrderDurationSeconds);
			UpdateOrderTimerBar();
			if (_orderTimerBar is not null)
			{
				_orderTimerBar.Visible = true;
			}
		}
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

		if (_cookingController is not null)
		{
			PickupItemDefinition? missingIngredient =
				_cookingController.GetFirstMissingIngredient();
			if (FetchTask is null || missingIngredient is null)
			{
				return false;
			}

			task = FetchTask;
			requestedItem = missingIngredient;
			return true;
		}

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
		if (
			_selectedCookingRecipe is { Ingredients.Count: > 1 } recipe
		)
		{
			ApplyRequestIcon(
				_requestIndicatorIcon,
				recipe.Ingredients[0],
				new Vector2(-9.0f, 0.0f),
				0.45f
			);
			ApplyRequestIcon(
				_requestIndicatorSecondaryIcon,
				recipe.Ingredients[1],
				new Vector2(9.0f, 0.0f),
				0.45f
			);
			_requestIndicatorSecondaryIcon.Visible = true;
		}
		else
		{
			ApplyRequestIcon(
				_requestIndicatorIcon,
				item,
				Vector2.Zero,
				0.65f
			);
			_requestIndicatorSecondaryIcon.Visible = false;
		}
		_requestIndicator.Visible = true;
		_requestIndicatorAnimation.Stop();
		_requestIndicatorAnimation.Frame = 0;
		_requestIndicatorAnimation.Play(
			RequestIndicatorOpenAnimation,
			RequestIndicatorOpenFramesPerSecond
		);
	}

	private static void ApplyRequestIcon(
		Sprite2D icon,
		PickupItemDefinition item,
		Vector2 position,
		float scaleMultiplier
	)
	{
		icon.Position = position;
		icon.Texture = item.Texture;
		icon.Modulate = item.Modulate;
		icon.Scale = item.VisualScale * scaleMultiplier;
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
			_requestIndicatorIcon.Position = Vector2.Zero;
		}
		if (GodotObject.IsInstanceValid(_requestIndicatorSecondaryIcon))
		{
			_requestIndicatorSecondaryIcon.Texture = null;
			_requestIndicatorSecondaryIcon.Visible = false;
		}
		if (
			_orderTimerBar is not null
			&& GodotObject.IsInstanceValid(_orderTimerBar)
		)
		{
			_orderTimerBar.Visible = false;
		}
		if (GodotObject.IsInstanceValid(_requestIndicatorAnimation))
		{
			_requestIndicatorAnimation.Stop();
			_requestIndicatorAnimation.Frame = 0;
		}
	}

	private bool TryBeginConsumption()
	{
		PickupItem? item = _socket.Item;
		if (
			!ConsumeDeliveredItem
			|| _isConsuming
			|| !IsAcceptingCustomerDelivery
			|| item?.Definition is null
			|| RequestedItem is null
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

		CustomerOrderOutcome outcome =
			item.Definition.Id == RequestedItem.Id
				? CustomerOrderOutcome.Correct
				: CustomerOrderOutcome.Wrong;
		_orderTimeRemaining = 0.0f;
		_isConsuming = true;
		StartOrderCooldown();
		CustomerOrderResolved?.Invoke(outcome);
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
		if (Mathf.IsZeroApprox(_orderCooldownRemaining))
		{
			ReconcileTask();
		}
	}

	private void ResolveMissedOrder()
	{
		_generation++;
		CancelCurrentTask();
		CustomerOrderResolved?.Invoke(CustomerOrderOutcome.Missed);
		StartOrderCooldown();
	}

	private void StartOrderCooldown()
	{
		_orderCooldownRemaining = Mathf.Max(0.0f, OrderCooldownSeconds);
		if (
			Mathf.IsZeroApprox(_orderCooldownRemaining)
			&& !_isConsuming
		)
		{
			ReconcileTask();
		}
	}

	private void UpdateOrderTimerBar()
	{
		if (_orderTimerBar is null)
		{
			return;
		}

		int frameCount = _orderTimerBar.Hframes * _orderTimerBar.Vframes;
		float duration = Mathf.Max(0.01f, OrderDurationSeconds);
		float elapsedRatio = 1.0f - (_orderTimeRemaining / duration);
		_orderTimerBar.Frame = Mathf.Clamp(
			Mathf.FloorToInt(elapsedRatio * frameCount),
			0,
			frameCount - 1
		);
	}
}
