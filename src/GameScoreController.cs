using System;
using System.Collections.Generic;
using Godot;

public partial class GameScoreController : CanvasLayer
{
    private readonly List<WorkstationTaskPublisher> _publishers = new();
    private Label _scoreLabel = null!;
    private GameOverController _gameOverController = null!;
    private int _score;

    [Export]
    public NodePath ScoreLabelPath { get; set; } = new("Score");

    [Export]
    public int CorrectOrderPoints { get; set; } = 1;

    [Export]
    public int FailedOrderPenalty { get; set; } = 1;

    [Export(PropertyHint.Range, "1,10000,1,or_greater")]
    public int MaximumScore { get; set; } = 100;

    [Export(PropertyHint.Range, "1,10000,1,or_greater")]
    public int StartingScore { get; set; } = 50;

    [Export]
    public NodePath GameOverControllerPath { get; set; } =
        new("../GameOverController");

    public int Score => _score;

    public override void _Ready()
    {
        _scoreLabel =
            GetNodeOrNull<Label>(ScoreLabelPath)
            ?? throw new InvalidOperationException(
                "GameScoreController requires a score label."
            );
        _gameOverController =
            GetNodeOrNull<GameOverController>(GameOverControllerPath)
            ?? throw new InvalidOperationException(
                "GameScoreController requires a game-over controller."
            );
        MaximumScore = Math.Max(1, MaximumScore);
        _score = Math.Clamp(StartingScore, 0, MaximumScore);
        UpdateScoreLabel();
        Callable.From(ConnectPublishers).CallDeferred();
    }

    public override void _ExitTree()
    {
        foreach (WorkstationTaskPublisher publisher in _publishers)
        {
            if (GodotObject.IsInstanceValid(publisher))
            {
                publisher.CustomerOrderResolved -= ApplyCustomerOrderOutcome;
            }
        }
        _publishers.Clear();
    }

    private void ConnectPublishers()
    {
        foreach (
            Node node in GetTree().GetNodesInGroup(
                WorkstationTaskPublisher.PublisherGroup
            )
        )
        {
            if (
                node is not WorkstationTaskPublisher publisher
                || !publisher.ConsumeDeliveredItem
            )
            {
                continue;
            }

            publisher.CustomerOrderResolved += ApplyCustomerOrderOutcome;
            _publishers.Add(publisher);
        }
    }

    public void ApplyCustomerOrderOutcome(CustomerOrderOutcome outcome)
    {
        int scoreDelta = outcome == CustomerOrderOutcome.Correct
            ? CorrectOrderPoints
            : -FailedOrderPenalty;
        _score = Math.Clamp(_score + scoreDelta, 0, MaximumScore);
        UpdateScoreLabel();
        if (_score == 0)
        {
            _gameOverController.TriggerGameOver();
        }
    }

    private void UpdateScoreLabel()
    {
        _scoreLabel.Text = $"Score: {_score} / {MaximumScore}";
    }
}
