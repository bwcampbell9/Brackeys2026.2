using System;
using Godot;

public partial class ChoppedShaderPreview : Control
{
    private static readonly StringName ChopProgressParameter = "chop_progress";
    private static readonly StringName ChopCountParameter = "chop_count";

    private Sprite2D _carrotPreview = null!;
    private Sprite2D _potatoPreview = null!;
    private HSlider _progressSlider = null!;
    private Label _progressLabel = null!;
    private HSlider _chopCountSlider = null!;
    private Label _chopCountLabel = null!;
    private CheckButton _autoLoop = null!;
    private ShaderMaterial _runtimeMaterial = null!;
    private float _playbackDirection = 1.0f;

    [Export]
    public ShaderMaterial? FractureMaterial { get; set; }

    [Export(PropertyHint.Range, "0.25,10,0.05,or_greater,suffix:s")]
    public float AnimationDuration { get; set; } = 2.0f;

    public override void _Ready()
    {
        _carrotPreview = GetNode<Sprite2D>("%CarrotPreview");
        _potatoPreview = GetNode<Sprite2D>("%PotatoPreview");
        _progressSlider = GetNode<HSlider>("%ProgressSlider");
        _progressLabel = GetNode<Label>("%ProgressLabel");
        _chopCountSlider = GetNode<HSlider>("%ChopCountSlider");
        _chopCountLabel = GetNode<Label>("%ChopCountLabel");
        _autoLoop = GetNode<CheckButton>("%AutoLoop");
        Button resetButton = GetNode<Button>("%ResetButton");

        _runtimeMaterial =
            FractureMaterial?.Duplicate() as ShaderMaterial
            ?? throw new InvalidOperationException(
                "Chopped shader preview requires a fracture shader material."
            );
        _carrotPreview.Material = _runtimeMaterial;
        _potatoPreview.Material = _runtimeMaterial;

        _progressSlider.ValueChanged += OnProgressChanged;
        _chopCountSlider.ValueChanged += OnChopCountChanged;
        resetButton.Pressed += ResetPreview;
        SetProgress((float)_progressSlider.Value);
        SetChopCount((int)_chopCountSlider.Value);
    }

    public override void _Process(double delta)
    {
        if (!_autoLoop.ButtonPressed)
        {
            return;
        }

        float progress =
            (float)_progressSlider.Value
            + _playbackDirection * (float)delta / AnimationDuration;
        if (progress >= 1.0f)
        {
            progress = 1.0f;
            _playbackDirection = -1.0f;
        }
        else if (progress <= 0.0f)
        {
            progress = 0.0f;
            _playbackDirection = 1.0f;
        }

        _progressSlider.Value = progress;
    }

    private void OnProgressChanged(double value)
    {
        SetProgress((float)value);
    }

    private void SetProgress(float progress)
    {
        float clampedProgress = Mathf.Clamp(progress, 0.0f, 1.0f);
        _runtimeMaterial.SetShaderParameter(
            ChopProgressParameter,
            clampedProgress
        );
        _progressLabel.Text = $"Chop progress: {clampedProgress:0.00}";
    }

    private void OnChopCountChanged(double value)
    {
        SetChopCount((int)value);
    }

    private void SetChopCount(int count)
    {
        _runtimeMaterial.SetShaderParameter(ChopCountParameter, count);
        _chopCountLabel.Text = $"Chops: {count}";
    }

    private void ResetPreview()
    {
        _playbackDirection = 1.0f;
        _progressSlider.Value = 0.0;
    }
}
