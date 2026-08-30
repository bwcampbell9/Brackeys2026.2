using Godot;

public partial class TitleScreen : Control
{
    private const string LevelOneScenePath = "res://scenes/level_1.tscn";
    private static readonly NodePath LevelOnePlayerPath = "Player";

    [Export(PropertyHint.Range, "0.1,2.0,0.05,or_greater")]
    private float _dropDuration = 0.65f;

    [Export(PropertyHint.Range, "0.0,1.0,0.05,or_greater")]
    private float _openDelay = 0.1f;

    [Export(PropertyHint.Range, "0.1,2.0,0.05,or_greater")]
    private float _openDuration = 0.85f;

    private Control _scroll = null!;
    private Control _parchmentMask = null!;
    private TextureRect _parchment = null!;
    private TextureRect _topRoll = null!;
    private TextureRect _bottomRoll = null!;
    private MenuBannerButton _cookButton = null!;
    private MenuBannerButton _exitButton = null!;
    private bool _menuEnabled;
    private bool _isTransitioning;

    public override void _Ready()
    {
        _scroll = GetNode<Control>("Scroll");
        _parchmentMask = GetNode<Control>("Scroll/ParchmentMask");
        _parchment = GetNode<TextureRect>("Scroll/ParchmentMask/Parchment");
        _topRoll = GetNode<TextureRect>("Scroll/TopRoll");
        _bottomRoll = GetNode<TextureRect>("Scroll/BottomRoll");
        _cookButton = GetNode<MenuBannerButton>("Scroll/ParchmentMask/CookButton");
        _exitButton = GetNode<MenuBannerButton>("Scroll/ParchmentMask/ExitButton");
        SetMenuEnabled(false);
        _cookButton.Pressed += OnCookPressed;
        _exitButton.Pressed += OnExitPressed;
        Input.Singleton.JoyConnectionChanged += OnJoyConnectionChanged;

        Vector2 scrollRestPosition = _scroll.Position;
        Vector2 topRollOpenPosition = _topRoll.Position;
        Vector2 bottomRollOpenPosition = _bottomRoll.Position;
        Vector2 maskOpenPosition = _parchmentMask.Position;
        Vector2 maskOpenSize = _parchmentMask.Size;
        Vector2 parchmentOpenPosition = _parchment.Position;

        float closedRollY = (topRollOpenPosition.Y + bottomRollOpenPosition.Y) * 0.5f;
        _topRoll.Position = new Vector2(topRollOpenPosition.X, closedRollY);
        _bottomRoll.Position = new Vector2(bottomRollOpenPosition.X, closedRollY);
        _parchmentMask.Position = new Vector2(maskOpenPosition.X, closedRollY + (_topRoll.Size.Y * 0.5f));
        _parchmentMask.Size = new Vector2(maskOpenSize.X, 0.0f);
        _parchment.Position = new Vector2(
            parchmentOpenPosition.X,
            parchmentOpenPosition.Y - (_parchmentMask.Position.Y - maskOpenPosition.Y)
        );
        _scroll.Position = scrollRestPosition - new Vector2(0.0f, Size.Y + _scroll.Size.Y);

        Tween tween = CreateTween();
        tween.TweenProperty(_scroll, "position", scrollRestPosition, _dropDuration)
            .SetTrans(Tween.TransitionType.Back)
            .SetEase(Tween.EaseType.Out);
        tween.TweenInterval(_openDelay);

        tween.SetParallel()
            .SetTrans(Tween.TransitionType.Cubic)
            .SetEase(Tween.EaseType.InOut);
        tween.TweenProperty(_topRoll, "position", topRollOpenPosition, _openDuration);
        tween.TweenProperty(_bottomRoll, "position", bottomRollOpenPosition, _openDuration);
        tween.TweenProperty(_parchmentMask, "position", maskOpenPosition, _openDuration);
        tween.TweenProperty(_parchmentMask, "size", maskOpenSize, _openDuration);
        tween.TweenProperty(_parchment, "position", parchmentOpenPosition, _openDuration);
        tween.Chain().TweenCallback(Callable.From(EnableMenu));
    }

    public override void _Input(InputEvent @event)
    {
        if (!MenuInputMode.Observe(@event) || !_menuEnabled)
        {
            return;
        }

        if (!MenuInputMode.IsControllerActive)
        {
            ReleaseMenuFocus();
            return;
        }

        if (!HasMenuFocus())
        {
            _cookButton.GrabFocus();
            GetViewport().SetInputAsHandled();
        }
    }

    public override void _ExitTree()
    {
        Input.Singleton.JoyConnectionChanged -= OnJoyConnectionChanged;
    }

    private void EnableMenu()
    {
        SetMenuEnabled(true);
        if (MenuInputMode.IsControllerActive)
        {
            _cookButton.GrabFocus();
        }
        else
        {
            ReleaseMenuFocus();
        }
    }

    private void SetMenuEnabled(bool enabled)
    {
        _menuEnabled = enabled;
        _cookButton.Disabled = !enabled;
        _exitButton.Disabled = !enabled;
    }

    private async void OnCookPressed()
    {
        if (_isTransitioning)
        {
            return;
        }

        _isTransitioning = true;
        SetMenuEnabled(false);

        CircleTransition transition = new();
        GetTree().Root.AddChild(transition);
        Vector2 closeCenter = _cookButton.GlobalPosition + (_cookButton.Size * 0.5f);
        Error result = await transition.TransitionToScene(
            LevelOneScenePath,
            LevelOnePlayerPath,
            closeCenter
        );
        if (result != Error.Ok && IsInstanceValid(this))
        {
            _isTransitioning = false;
            SetMenuEnabled(true);
            if (MenuInputMode.IsControllerActive)
            {
                _cookButton.GrabFocus();
            }
        }
    }

    private void OnExitPressed()
    {
        GetTree().Quit();
    }

    private bool HasMenuFocus()
    {
        return _cookButton.HasFocus()
            || _exitButton.HasFocus();
    }

    private void ReleaseMenuFocus()
    {
        _cookButton.ReleaseFocus();
        _exitButton.ReleaseFocus();
    }

    private void OnJoyConnectionChanged(long device, bool connected)
    {
        if (connected || Input.GetConnectedJoypads().Count > 0)
        {
            return;
        }

        MenuInputMode.DeactivateController();
        ReleaseMenuFocus();
    }
}