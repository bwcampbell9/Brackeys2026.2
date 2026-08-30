using System;
using Godot;

public partial class TutorialLevelController : Node
{
    private const string TitleScenePath = "res://scenes/title_screen.tscn";

    private enum TutorialPhase
    {
        ConfigureBoard,
        WorkerFetchingIngredient,
        WorkerChopping,
        WorkerReturningKnife,
        InterceptDelivery,
        Complete,
    }

    [Export]
    public NodePath BoardPublisherPath { get; set; } = new("../CuttingBoard/WorkstationTaskPublisher");

    [Export]
    public NodePath BoardSocketPath { get; set; } = new("../CuttingBoard/PickupSocket");

    [Export]
    public NodePath WorkerPath { get; set; } = new("../TutorialWorker");

    [Export]
    public NodePath PotatoSourcePath { get; set; } = new("../PotatoContainer/NpcItemSource");

    [Export]
    public NodePath CarrotSourcePath { get; set; } = new("../CarrotContainer/NpcItemSource");

    [Export]
    public NodePath KnifeSourcePath { get; set; } = new("../KnifeContainer/NpcItemSource");

    [Export]
    public NodePath CustomerPublisherPath { get; set; } = new("../TutorialCustomer/WorkstationTaskPublisher");

    [Export]
    public NodePath PromptPath { get; set; } = new("../TutorialPrompt");

    private WorkstationTaskPublisher _boardPublisher = null!;
    private PickupSocket _boardSocket = null!;
    private NpcTaskRunner _workerRunner = null!;
    private PickupCarrier _workerCarrier = null!;
    private ContainerItemSource _potatoSource = null!;
    private ContainerItemSource _carrotSource = null!;
    private ContainerItemSource _knifeSource = null!;
    private WorkstationTaskPublisher _customerPublisher = null!;
    private Label _prompt = null!;
    private TutorialPhase _phase;
    private bool _transitioning;

    public override void _Ready()
    {
        _boardPublisher = GetNode<WorkstationTaskPublisher>(BoardPublisherPath);
        _boardSocket = GetNode<PickupSocket>(BoardSocketPath);
        CharacterBody2D worker = GetNode<CharacterBody2D>(WorkerPath);
        _workerRunner = worker.GetNode<NpcTaskRunner>("NpcTaskRunner");
        _workerCarrier = worker.GetNode<PickupCarrier>("PickupCarrier");
        _potatoSource = GetNode<ContainerItemSource>(PotatoSourcePath);
        _carrotSource = GetNode<ContainerItemSource>(CarrotSourcePath);
        _knifeSource = GetNode<ContainerItemSource>(KnifeSourcePath);
        _customerPublisher = GetNode<WorkstationTaskPublisher>(CustomerPublisherPath);
        _prompt = GetNode<Label>(PromptPath);

        _potatoSource.ItemDefinition = GD.Load<PickupItemDefinition>("res://resources/items/potato.tres");
        _carrotSource.ItemDefinition = GD.Load<PickupItemDefinition>("res://resources/items/carrot.tres");
        _workerRunner.Personality = new NpcPersonality
        {
            FailureChance = 0.0f,
            FailureTendencies = new Godot.Collections.Array<NpcFailureTendency>
            {
                new NpcFailureTendency
                {
                    Mode = NpcTaskFailureMode.WrongFetchedItem,
                    Weight = 1.0f,
                },
            },
        };
        _knifeSource.ItemDefinition = null;
        _customerPublisher.CustomerOrderResolved += OnCustomerOrderResolved;
        SetPrompt("Hold Q at the cutting board to choose an order.", _boardPublisher.GlobalPosition + Vector2.Up * 92.0f);
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_customerPublisher))
        {
            _customerPublisher.CustomerOrderResolved -= OnCustomerOrderResolved;
        }
    }

    public override void _Process(double delta)
    {
        if (_transitioning)
        {
            return;
        }

        switch (_phase)
        {
            case TutorialPhase.ConfigureBoard:
                UpdateConfigureBoard();
                break;
            case TutorialPhase.WorkerFetchingIngredient:
                UpdateWorkerFetchingIngredient();
                break;
            case TutorialPhase.WorkerChopping:
                UpdateWorkerChopping();
                break;
            case TutorialPhase.InterceptDelivery:
                UpdateInterceptDelivery();
                break;
        }
    }

    private void UpdateConfigureBoard()
    {
        if (_boardPublisher.CurrentTaskId == 0)
        {
            return;
        }

        _phase = TutorialPhase.WorkerFetchingIngredient;
        SetPrompt("A worker is collecting the ingredients.", _workerRunner.GetParent<Node2D>().GlobalPosition + Vector2.Up * 100.0f);
    }

    private void UpdateWorkerFetchingIngredient()
    {
        if (_boardSocket.Item?.Definition?.Id != "potato")
        {
            return;
        }

        _knifeSource.ItemDefinition = GD.Load<PickupItemDefinition>("res://resources/items/knife.tres");
        _phase = TutorialPhase.WorkerChopping;
        SetPrompt("The worker is chopping the correct ingredient.", _boardPublisher.GlobalPosition + Vector2.Up * 92.0f);
    }

    private void UpdateWorkerChopping()
    {
        if (_boardSocket.Item?.Definition?.Id != "chopped_potatoes")
        {
            return;
        }

        _workerRunner.Personality = new NpcPersonality
        {
            FailureChance = 1.0f,
            FailureTendencies = new Godot.Collections.Array<NpcFailureTendency>
            {
                new NpcFailureTendency
                {
                    Mode = NpcTaskFailureMode.WrongFetchedItem,
                    Weight = 1.0f,
                },
            },
        };
        _knifeSource.ItemDefinition = null;
        _potatoSource.ItemDefinition = null;
        _carrotSource.ItemDefinition = GD.Load<PickupItemDefinition>("res://resources/items/chopped_carrots.tres");
        _phase = TutorialPhase.InterceptDelivery;
        SetPrompt(
            "The worker has grabbed the wrong order. Take it from them before they deliver it!",
            _workerRunner.GetParent<Node2D>().GlobalPosition + Vector2.Up * 100.0f
        );
        GetTree().CreateTimer(0.25).Timeout += WatchForInterception;
    }

    private void UpdateInterceptDelivery()
    {
        PickupItem? heldItem = _workerCarrier.HeldItem;
        if (
            heldItem?.Definition?.Id != "chopped_carrots"
            || _workerRunner.State != NpcWorkerState.NavigatingToDestination
        )
        {
            return;
        }

        _phase = TutorialPhase.Complete;
        SetPrompt(
            "The worker has grabbed the wrong order. Take it from them before they deliver it!",
            _workerRunner.GetParent<Node2D>().GlobalPosition + Vector2.Up * 100.0f
        );
        GetTree().CreateTimer(0.25).Timeout += WatchForInterception;
    }

    public void OnWrongItemTaken()
    {
        if (_transitioning)
        {
            return;
        }

        _workerRunner.CancelCurrentTaskAndReset();
        _customerPublisher.ClearCurrentTask();
        _carrotSource.ItemDefinition = null;
        _potatoSource.ItemDefinition = GD.Load<PickupItemDefinition>("res://resources/items/chopped_potatoes.tres");
        _customerPublisher.RequestedItem = GD.Load<PickupItemDefinition>("res://resources/items/chopped_potatoes.tres");
        _workerRunner.Personality = new NpcPersonality
        {
            FailureChance = 0.0f,
        };
        _prompt.Hide();
        _phase = TutorialPhase.Complete;
        _customerPublisher.TryPublishNextTask();
    }

    private void WatchForInterception()
    {
        if (_transitioning || _phase != TutorialPhase.Complete)
        {
            return;
        }

        if (_workerCarrier.HeldItem is null)
        {
            OnWrongItemTaken();
            return;
        }

        GetTree().CreateTimer(0.25).Timeout += WatchForInterception;
    }

    private void OnCustomerOrderResolved(CustomerOrderOutcome outcome)
    {
        if (outcome == CustomerOrderOutcome.Wrong)
        {
            SetPrompt("Too late. The customer received the wrong order.", _customerPublisher.GlobalPosition + Vector2.Up * 100.0f);
            TransitionToTitle();
        }
    }

    private async void TransitionToTitle()
    {
        if (_transitioning)
        {
            return;
        }

        _transitioning = true;
        await ToSignal(GetTree().CreateTimer(1.2), SceneTreeTimer.SignalName.Timeout);
        GetTree().ChangeSceneToFile(TitleScenePath);
    }

    private void SetPrompt(string text, Vector2 position)
    {
        _prompt.Text = text;
        _prompt.GlobalPosition = position;
        _prompt.Show();
    }
}