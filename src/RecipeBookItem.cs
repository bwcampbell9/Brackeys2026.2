using System;
using Godot;

public partial class RecipeBookItem : PickupItem
{
    private static readonly StringName OpenAnimation = "open";
    private static readonly StringName PreviousPageAction =
        "cookbook_previous_page";
    private static readonly StringName NextPageAction =
        "cookbook_next_page";
    private static readonly Vector2 HiddenOverlayPosition =
        new(0.0f, -304.0f);

    private AnimatedSprite2D _sprite = null!;
    private AudioStreamPlayer2D _openAudio = null!;
    private AudioStreamPlayer2D _closeAudio = null!;
    private AudioStreamPlayer2D _forwardPageAudio = null!;
    private AudioStreamPlayer2D _backwardPageAudio = null!;
    private Control _overlayRoot = null!;
    private TextureRect _overlayImage = null!;
    private TextureRect _secondPageImage = null!;
    private Button _previousPageButton = null!;
    private Button _nextPageButton = null!;
    private Tween? _overlayTween;
    private bool _overlayShownForPlayer;
    private int _pageIndex;

    [Export(PropertyHint.Range, "0.05,2,0.01,or_greater")]
    public float OverlayShowDuration { get; set; } = 0.35f;

    [Export(PropertyHint.Range, "0.05,2,0.01,or_greater")]
    public float OverlayHideDuration { get; set; } = 0.25f;

    public bool IsOpening { get; private set; }

    public bool IsClosing { get; private set; }

    public bool IsOpen { get; private set; }

    public override void _Ready()
    {
        base._Ready();
        _sprite = GetNode<AnimatedSprite2D>("AnimatedSprite2D");
        _openAudio = GetNode<AudioStreamPlayer2D>("OpenCookbookAudio");
        _closeAudio = GetNode<AudioStreamPlayer2D>("CloseCookbookAudio");
        _forwardPageAudio = GetNode<AudioStreamPlayer2D>("ForwardPageAudio");
        _backwardPageAudio = GetNode<AudioStreamPlayer2D>("BackwardPageAudio");
        _overlayRoot = GetNode<Control>("RecipeOverlay/OverlayRoot");
        _overlayImage = _overlayRoot.GetNode<TextureRect>("Book");
        _secondPageImage = _overlayRoot.GetNode<TextureRect>("PageTwo");
        _previousPageButton = _overlayRoot.GetNode<Button>("PreviousPageButton");
        _nextPageButton = _overlayRoot.GetNode<Button>("NextPageButton");
        _previousPageButton.Pressed += ShowPreviousPage;
        _nextPageButton.Pressed += ShowNextPage;

        if (
            !_sprite.SpriteFrames.HasAnimation(OpenAnimation)
            || _sprite.SpriteFrames.GetFrameCount(OpenAnimation) != 6
            || _sprite.SpriteFrames.GetAnimationLoopMode(OpenAnimation)
                != SpriteFrames.LoopMode.None
        )
        {
            throw new InvalidOperationException(
                "RecipeBookItem requires a non-looping six-frame 'open' animation."
            );
        }

        _sprite.Animation = OpenAnimation;
        _sprite.Frame = 0;
        _sprite.AnimationFinished += OnAnimationFinished;
        _overlayRoot.Position = HiddenOverlayPosition;
        _overlayRoot.Visible = false;
        SetPage(0);
        ApplyOverlayDefinition();
    }

    public override void _Input(InputEvent @event)
    {
        if (!_overlayShownForPlayer)
        {
            return;
        }

        if (@event.IsActionPressed(PreviousPageAction))
        {
            ShowPreviousPage();
            GetViewport().SetInputAsHandled();
        }
        else if (@event.IsActionPressed(NextPageAction))
        {
            ShowNextPage();
            GetViewport().SetInputAsHandled();
        }
    }

    protected override void OnPickedUp()
    {
        RefreshOverlayVisibility();
    }

    protected override void OnAttachmentMoved()
    {
        RefreshOverlayVisibility();
    }

    protected override void OnThrown()
    {
        RefreshOverlayVisibility();
    }

    protected override void OnDefinitionApplied()
    {
        ApplyOverlayDefinition();
    }

    public override bool TrySecondaryInteract()
    {
        if (!IsCarried || IsOpening || IsClosing)
        {
            return false;
        }

        if (IsOpen)
        {
            IsClosing = true;
            _sprite.PlayBackwards(OpenAnimation);
            _closeAudio.Play();
        }
        else
        {
            IsOpening = true;
            SetPage(0);
            _sprite.Play(OpenAnimation);
            _openAudio.Play();
        }

        return true;
    }

    private void OnAnimationFinished()
    {
        if (_sprite.Animation != OpenAnimation)
        {
            return;
        }

        if (IsClosing)
        {
            IsClosing = false;
            IsOpen = false;
        }
        else if (IsOpening)
        {
            IsOpening = false;
            IsOpen = true;
        }

        RefreshOverlayVisibility();
    }

    private void RefreshOverlayVisibility()
    {
        bool shouldShow =
            CurrentCarrier?.GetParent() is Player
            && IsOpen
            && !IsOpening
            && !IsClosing;
        if (shouldShow == _overlayShownForPlayer)
        {
            return;
        }

        _overlayShownForPlayer = shouldShow;
        _overlayTween?.Kill();
        _overlayTween = CreateTween()
            .SetTrans(Tween.TransitionType.Cubic)
            .SetEase(
                shouldShow
                    ? Tween.EaseType.Out
                    : Tween.EaseType.In
            );

        if (shouldShow)
        {
            if (!_overlayRoot.Visible)
            {
                _overlayRoot.Position = HiddenOverlayPosition;
                _overlayRoot.Visible = true;
            }

            _overlayTween.TweenProperty(
                _overlayRoot,
                new NodePath("position"),
                Vector2.Zero,
                OverlayShowDuration
            );
            return;
        }

        _overlayTween.TweenProperty(
            _overlayRoot,
            new NodePath("position"),
            HiddenOverlayPosition,
            OverlayHideDuration
        );
        _overlayTween.TweenCallback(Callable.From(FinishHidingOverlay));
    }

    private void FinishHidingOverlay()
    {
        if (!_overlayShownForPlayer)
        {
            _overlayRoot.Visible = false;
        }

        _overlayTween = null;
    }

    private void ShowPreviousPage()
    {
        if (_pageIndex == 0)
        {
            return;
        }

        SetPage(0);
        _backwardPageAudio.Play();
    }

    private void ShowNextPage()
    {
        if (_pageIndex == 1)
        {
            return;
        }

        SetPage(1);
        _forwardPageAudio.Play();
    }

    private void SetPage(int pageIndex)
    {
        _pageIndex = Mathf.Clamp(pageIndex, 0, 1);
        _overlayImage.Visible = _pageIndex == 0;
        _secondPageImage.Visible = _pageIndex == 1;
        _previousPageButton.Disabled = _pageIndex == 0;
        _nextPageButton.Disabled = _pageIndex == 1;
    }

    private void ApplyOverlayDefinition()
    {
        if (_overlayImage is null || Definition is null)
        {
            return;
        }

        _overlayImage.Material = Definition.VisualMaterial;
        _overlayImage.Modulate = Definition.Modulate;
        _secondPageImage.Material = Definition.VisualMaterial;
        _secondPageImage.Modulate = Definition.Modulate;
    }
}
