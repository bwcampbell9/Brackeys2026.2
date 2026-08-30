using System;
using Godot;

public partial class CuttingBoardProcessPresentation : Node
{
    private static readonly StringName ChopProgressParameter = "chop_progress";

    private TimedItemProcessAction _processAction = null!;
    private ProgressBar _progressBar = null!;
    private AudioStreamPlayer2D _choppingAudio = null!;
    private Node2D _board = null!;
    private PickupItem? _knife;
    private PickupItem? _processingItem;
    private Material? _originalItemMaterial;
    private ShaderMaterial? _chopMaterial;
    private bool _usesProcessingAnimation;
    private Tween? _knifeTween;

    [Export]
    public NodePath ProcessActionPath { get; set; } =
        new("../InteractionTarget/ProcessItemAction");

    [Export]
    public NodePath ProgressBarPath { get; set; } = new("../ProgressBar");

    [Export]
    public NodePath ChoppingAudioPath { get; set; } = new("../ChoppingAudio");

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
        _choppingAudio =
            GetNodeOrNull<AudioStreamPlayer2D>(ChoppingAudioPath)
            ?? throw new InvalidOperationException(
                "CuttingBoardProcessPresentation requires a chopping audio player."
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
        StartChopPreview();
        _progressBar.Value = 0.0;
        _progressBar.Visible = true;
        StartKnifeAnimation();
        _choppingAudio.Play();
    }

    private void OnProgressChanged(float progress)
    {
        float clampedProgress = Mathf.Clamp(progress, 0.0f, 1.0f);
        _progressBar.Value = clampedProgress * 100.0f;
        _chopMaterial?.SetShaderParameter(
            ChopProgressParameter,
            clampedProgress
        );
    }

    private void OnProcessingCanceled()
    {
        EndChopPreview(restoreOriginalMaterial: true);
        ResetPresentation();
    }

    private void OnProcessingCompleted(PickupItem item)
    {
        EndChopPreview(restoreOriginalMaterial: false);
        ResetPresentation();

        if (item is BabyPickupItem)
        {
            GetTree().CallGroup(
                GameOverController.GameOverGroup,
                nameof(GameOverController.TriggerGameOverAt),
                item.GlobalPosition
            );
        }
    }

    private void StartChopPreview()
    {
        _processingItem =
            _processAction.ActiveItem
            ?? throw new InvalidOperationException(
                "Cutting presentation requires an active item when processing starts."
            );
        PickupItemDefinition definition =
            _processingItem.Definition
            ?? throw new InvalidOperationException(
                "Cutting presentation requires the active item to have a definition."
            );
        ItemTransformation transformation =
            _processAction.Recipe?.Transformation
            ?? throw new InvalidOperationException(
                "Cutting presentation requires a processing transformation."
            );
        if (definition.ProcessingSpriteFrames is not null)
        {
            _usesProcessingAnimation = true;
            _processingItem.PlayProcessingAnimation(
                definition.ProcessingSpriteFrames
            );
            return;
        }

        ShaderMaterial sourceMaterial =
            transformation.FallbackMaterial as ShaderMaterial
            ?? transformation.Resolve(definition).VisualMaterial as ShaderMaterial
            ?? throw new InvalidOperationException(
                "Cutting presentation requires a shader material."
            );

        _originalItemMaterial = _processingItem.GetVisualMaterial();
        _chopMaterial =
            sourceMaterial.Duplicate() as ShaderMaterial
            ?? throw new InvalidOperationException(
                "Cutting presentation could not duplicate the chop material."
            );
        _chopMaterial.SetShaderParameter(ChopProgressParameter, 0.0f);
        _processingItem.SetVisualMaterial(_chopMaterial);
    }

    private void EndChopPreview(bool restoreOriginalMaterial)
    {
        if (
            restoreOriginalMaterial
            && GodotObject.IsInstanceValid(_processingItem)
        )
        {
            if (_usesProcessingAnimation)
            {
                _processingItem!.RestoreDefinitionVisual();
            }
            else
            {
                _processingItem!.SetVisualMaterial(_originalItemMaterial);
            }
        }

        _processingItem = null;
        _originalItemMaterial = null;
        _chopMaterial = null;
        _usesProcessingAnimation = false;
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
        EndChopPreview(restoreOriginalMaterial: true);
        if (GodotObject.IsInstanceValid(_choppingAudio))
        {
            _choppingAudio.Stop();
        }

        if (
            GodotObject.IsInstanceValid(_knife)
            && !_knife!.IsAvailable
        )
        {
            _knife.ResetAttachmentPresentation();
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
