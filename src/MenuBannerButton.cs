using Godot;

public partial class MenuBannerButton : TextureButton
{
    [Export(PropertyHint.Range, "-12,12,0.5")]
    public float HoverRotationDegrees { get; set; } = -3.0f;

    [Export(PropertyHint.Range, "0.05,1,0.05,or_greater")]
    public float TiltDuration { get; set; } = 0.18f;

    [Export(PropertyHint.Range, "1,1.2,0.01")]
    public float FocusScale { get; set; } = 1.06f;

    [Export]
    public Color FocusColor { get; set; } = new(1.0f, 0.88f, 0.55f);

    private Tween? _presentationTween;
    private bool _hasFocus;
    private bool _isHovered;

    public override void _Ready()
    {
        PivotOffset = Size * 0.5f;
        MouseEntered += OnMouseEntered;
        MouseExited += OnMouseExited;
        FocusEntered += OnFocusEntered;
        FocusExited += OnFocusExited;
    }

    private void OnMouseEntered()
    {
        _isHovered = true;
        UpdatePresentation();
    }

    private void OnMouseExited()
    {
        _isHovered = false;
        UpdatePresentation();
    }

    private void OnFocusEntered()
    {
        _hasFocus = true;
        UpdatePresentation();
    }

    private void OnFocusExited()
    {
        _hasFocus = false;
        UpdatePresentation();
    }

    private void UpdatePresentation()
    {
        _presentationTween?.Kill();
        _presentationTween = CreateTween()
            .SetParallel()
            .SetTrans(Tween.TransitionType.Back)
            .SetEase(Tween.EaseType.Out);

        bool isControllerFocused = _hasFocus && MenuInputMode.IsControllerActive;
        bool isHighlighted = _isHovered || isControllerFocused;
        float targetRotation = Mathf.DegToRad(isHighlighted ? HoverRotationDegrees : 0.0f);
        Vector2 targetScale = Vector2.One * (isControllerFocused ? FocusScale : 1.0f);
        Color targetColor = isHighlighted ? FocusColor : Colors.White;

        _presentationTween.TweenProperty(this, "rotation", targetRotation, TiltDuration);
        _presentationTween.TweenProperty(this, "scale", targetScale, TiltDuration);
        _presentationTween.TweenProperty(this, "self_modulate", targetColor, TiltDuration);
    }
}
