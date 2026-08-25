using System;
using Godot;

public partial class CuttingBoardProcessPresentation : Node
{
    private TimedItemProcessAction _processAction = null!;
    private ProgressBar _progressBar = null!;
    private Node2D _board = null!;
    private PickupItem? _knife;
    private Tween? _knifeTween;

    [Export]
    public NodePath ProcessActionPath { get; set; } =
        new("../InteractionTarget/ProcessItemAction");

    [Export]
    public NodePath ProgressBarPath { get; set; } = new("../ProgressBar");

    [Export]
    public Vector2 RaisedOffset { get; set; } = new(-10.0f, -28.0f);

    [Export]
    public Vector2 StrikeOffset { get; set; } = new(8.0f, -6.0f);

    [Export(PropertyHint.Range, "0.05,1,0.01,or_greater")]
    public float StrokeDuration { get; set; } = 0.12f;

    public override void _Ready()
    {
        _board =
            GetParentOrNull<Node2D>()
            ?? throw new InvalidOperationException(
                "CuttingBoardProcessPresentation requires a Node2D parent."
            );
        _processAction =
            GetNodeOrNull<TimedItemProcessAction>(ProcessActionPath)
            ?? throw new InvalidOperationException(
                "CuttingBoardProcessPresentation requires a timed process action."
            );
        _progressBar =
            GetNodeOrNull<ProgressBar>(ProgressBarPath)
            ?? throw new InvalidOperationException(
                "CuttingBoardProcessPresentation requires a progress bar."
            );

        _processAction.ProcessingStarted += OnProcessingStarted;
        _processAction.ProgressChanged += OnProgressChanged;
        _processAction.ProcessingCanceled += OnProcessingCanceled;
        _processAction.ProcessingCompleted += OnProcessingCompleted;
        ResetPresentation();
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_processAction))
        {
            _processAction.ProcessingStarted -= OnProcessingStarted;
            _processAction.ProgressChanged -= OnProgressChanged;
            _processAction.ProcessingCanceled -= OnProcessingCanceled;
            _processAction.ProcessingCompleted -= OnProcessingCompleted;
        }

        ResetPresentation();
    }

    private void OnProcessingStarted()
    {
        _knife = _processAction.ActiveTool;
        _progressBar.Value = 0.0;
        _progressBar.Visible = true;
        StartKnifeAnimation();
    }

    private void OnProgressChanged(float progress)
    {
        _progressBar.Value = Mathf.Clamp(progress, 0.0f, 1.0f) * 100.0f;
    }

    private void OnProcessingCanceled()
    {
        ResetPresentation();
    }

    private void OnProcessingCompleted(PickupItem item)
    {
        ResetPresentation();
    }

    private void StartKnifeAnimation()
    {
        if (_knife is null)
        {
            return;
        }

        Vector2 raisedPosition = _board.GlobalPosition + RaisedOffset;
        Vector2 strikePosition = _board.GlobalPosition + StrikeOffset;
        _knife.GlobalPosition = raisedPosition;
        _knife.GlobalRotation = -0.8f;

        _knifeTween = _knife.StartMotionTween().SetLoops();
        _knifeTween.SetTrans(Tween.TransitionType.Sine);
        _knifeTween.SetEase(Tween.EaseType.InOut);
        _knifeTween.TweenProperty(
            _knife,
            new NodePath("global_position"),
            strikePosition,
            StrokeDuration
        );
        _knifeTween
            .Parallel()
            .TweenProperty(
                _knife,
                new NodePath("global_rotation"),
                0.25f,
                StrokeDuration
            );
        _knifeTween.TweenProperty(
            _knife,
            new NodePath("global_position"),
            raisedPosition,
            StrokeDuration
        );
        _knifeTween
            .Parallel()
            .TweenProperty(
                _knife,
                new NodePath("global_rotation"),
                -0.8f,
                StrokeDuration
            );
    }

    private void ResetPresentation()
    {
        if (GodotObject.IsInstanceValid(_knife))
        {
            _knife!.ResetAttachmentPresentation();
        }
        else
        {
            _knifeTween?.Kill();
        }

        _knifeTween = null;
        _knife = null;
        if (GodotObject.IsInstanceValid(_progressBar))
        {
            _progressBar.Value = 0.0;
            _progressBar.Visible = false;
        }
    }
}
