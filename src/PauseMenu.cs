using Godot;

public partial class PauseMenu : CanvasLayer
{
	private static readonly StringName PauseAction = "pause";
	private static readonly StringName CancelAction = "ui_cancel";
	private static readonly StringName AcceptAction = "ui_accept";
	private const string TitleScenePath = "res://scenes/title_screen.tscn";

	private MenuBannerButton _resumeButton = null!;
	private MenuBannerButton _titleButton = null!;
	private MenuBannerButton _quitButton = null!;
	private PlayerInputManager _playerInputManager = null!;
	private Control _scroll = null!;
	private Control _parchmentMask = null!;
	private TextureRect _parchment = null!;
	private TextureRect _topRoll = null!;
	private TextureRect _bottomRoll = null!;
	private Tween? _scrollTween;
	private Vector2 _scrollRestPosition;
	private Vector2 _topRollOpenPosition;
	private Vector2 _bottomRollOpenPosition;
	private Vector2 _maskOpenPosition;
	private Vector2 _maskOpenSize;
	private Vector2 _parchmentOpenPosition;
	private bool _isOpen;
	private bool _isTransitioning;
	private bool _resumePending;
	private bool _blockingActionReleaseObserved;
	private StringName _resumeBlockingAction = "";

	[Export]
	public NodePath PlayerInputManagerPath { get; set; } = "../Player/InputManager";

	[Export(PropertyHint.Range, "0.1,2.0,0.05,or_greater")]
	public float DropDuration { get; set; } = 0.3f;

	[Export(PropertyHint.Range, "0.0,1.0,0.05,or_greater")]
	public float OpenDelay { get; set; } = 0.048f;

	[Export(PropertyHint.Range, "0.1,2.0,0.05,or_greater")]
	public float OpenDuration { get; set; } = 0.39f;

	public override void _Ready()
	{
		ProcessMode = ProcessModeEnum.Always;
		_playerInputManager = GetNode<PlayerInputManager>(PlayerInputManagerPath);
		_scroll = GetNode<Control>("Overlay/Scroll");
		_parchmentMask = GetNode<Control>("Overlay/Scroll/ParchmentMask");
		_parchment = GetNode<TextureRect>("Overlay/Scroll/ParchmentMask/Parchment");
		_topRoll = GetNode<TextureRect>("Overlay/Scroll/TopRoll");
		_bottomRoll = GetNode<TextureRect>("Overlay/Scroll/BottomRoll");
		_resumeButton = GetNode<MenuBannerButton>("Overlay/Scroll/ParchmentMask/ResumeButton");
		_titleButton = GetNode<MenuBannerButton>("Overlay/Scroll/ParchmentMask/TitleButton");
		_quitButton = GetNode<MenuBannerButton>("Overlay/Scroll/ParchmentMask/QuitButton");

		_scrollRestPosition = _scroll.Position;
		_topRollOpenPosition = _topRoll.Position;
		_bottomRollOpenPosition = _bottomRoll.Position;
		_maskOpenPosition = _parchmentMask.Position;
		_maskOpenSize = _parchmentMask.Size;
		_parchmentOpenPosition = _parchment.Position;

		_resumeButton.Pressed += ResumeFromSelection;
		_titleButton.Pressed += ReturnToTitle;
		_quitButton.Pressed += QuitGame;
		Input.Singleton.JoyConnectionChanged += OnJoyConnectionChanged;
		Visible = false;
	}

	public override void _Process(double delta)
	{
		if (!_resumePending)
		{
			return;
		}

		if (Input.IsActionPressed(_resumeBlockingAction))
		{
			_blockingActionReleaseObserved = false;
			return;
		}

		if (!_blockingActionReleaseObserved)
		{
			_blockingActionReleaseObserved = true;
			return;
		}

		_resumePending = false;
		_blockingActionReleaseObserved = false;
		_resumeBlockingAction = "";
		GetTree().Paused = false;
	}

	public override void _Input(InputEvent @event)
	{
		if (!MenuInputMode.Observe(@event) || !_isOpen)
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
			_resumeButton.GrabFocus();
			GetViewport().SetInputAsHandled();
		}
	}

	public override void _UnhandledInput(InputEvent @event)
	{
		bool pausePressed = @event.IsActionPressed(PauseAction);
		bool cancelPressed = _isOpen && @event.IsActionPressed(CancelAction);
		if (_isTransitioning && (pausePressed || cancelPressed))
		{
			GetViewport().SetInputAsHandled();
			return;
		}

		if (!pausePressed && !cancelPressed)
		{
			return;
		}

		if (_isOpen)
		{
			if (cancelPressed)
			{
				BeginResume(CancelAction);
			}
			else
			{
				CloseMenu();
			}
		}
		else if (!GetTree().Paused)
		{
			OpenMenu();
		}

		GetViewport().SetInputAsHandled();
	}

	public override void _ExitTree()
	{
		Input.Singleton.JoyConnectionChanged -= OnJoyConnectionChanged;
		if (_isOpen || _resumePending)
		{
			GetTree().Paused = false;
		}
	}

	private void OpenMenu()
	{
		_resumePending = false;
		_blockingActionReleaseObserved = false;
		_resumeBlockingAction = "";
		_isOpen = true;
		Visible = true;
		GetTree().Paused = true;
		if (MenuInputMode.IsControllerActive)
		{
			_resumeButton.GrabFocus();
		}
		else
		{
			ReleaseMenuFocus();
		}
		PlayScrollOpening();
	}

	private void CloseMenu()
	{
		_resumePending = false;
		_blockingActionReleaseObserved = false;
		_resumeBlockingAction = "";
		_scrollTween?.Kill();
		GetTree().Paused = false;
		_isOpen = false;
		Visible = false;
	}

	private void ResumeFromSelection()
	{
		BeginResume(AcceptAction);
	}

	private void BeginResume(StringName blockingAction)
	{
		_playerInputManager.SuppressCurrentGameplayInput();
		_scrollTween?.Kill();
		_isOpen = false;
		Visible = false;
		_resumePending = true;
		_blockingActionReleaseObserved = false;
		_resumeBlockingAction = blockingAction;
	}

	private async void ReturnToTitle()
	{
		if (_isTransitioning)
		{
			return;
		}

		_isTransitioning = true;
		_resumeButton.Disabled = true;
		_titleButton.Disabled = true;
		_quitButton.Disabled = true;

		Node2D player = _playerInputManager.GetParent<Node2D>();
		Vector2 closeCenter = player.GetGlobalTransformWithCanvas().Origin;
		CircleTransition transition = new();
		GetTree().Root.AddChild(transition);
		Error result = await transition.TransitionToScene(
			TitleScenePath,
			new NodePath(""),
			closeCenter,
			revealAtViewportCenter: true,
			unpauseBeforeSceneChange: true
		);
		if (result == Error.Ok || !IsInstanceValid(this))
		{
			return;
		}

		GetTree().Paused = true;
		_isTransitioning = false;
		_resumeButton.Disabled = false;
		_titleButton.Disabled = false;
		_quitButton.Disabled = false;
	}

	private void QuitGame()
	{
		GetTree().Quit();
	}

	private void PlayScrollOpening()
	{
		_scrollTween?.Kill();

		float closedRollY = (_topRollOpenPosition.Y + _bottomRollOpenPosition.Y) * 0.5f;
		_topRoll.Position = new Vector2(_topRollOpenPosition.X, closedRollY);
		_bottomRoll.Position = new Vector2(_bottomRollOpenPosition.X, closedRollY);
		_parchmentMask.Position = new Vector2(
			_maskOpenPosition.X,
			closedRollY + (_topRoll.Size.Y * 0.5f)
		);
		_parchmentMask.Size = new Vector2(_maskOpenSize.X, 0.0f);
		_parchment.Position = new Vector2(
			_parchmentOpenPosition.X,
			_parchmentOpenPosition.Y - (_parchmentMask.Position.Y - _maskOpenPosition.Y)
		);
		_scroll.Position = _scrollRestPosition - new Vector2(
			0.0f,
			GetViewport().GetVisibleRect().Size.Y + _scroll.Size.Y
		);

		_scrollTween = CreateTween();
		_scrollTween.SetPauseMode(Tween.TweenPauseMode.Process);
		_scrollTween.TweenProperty(_scroll, "position", _scrollRestPosition, DropDuration)
			.SetTrans(Tween.TransitionType.Back)
			.SetEase(Tween.EaseType.Out);
		_scrollTween.TweenInterval(OpenDelay);
		_scrollTween.SetParallel()
			.SetTrans(Tween.TransitionType.Cubic)
			.SetEase(Tween.EaseType.InOut);
		_scrollTween.TweenProperty(_topRoll, "position", _topRollOpenPosition, OpenDuration);
		_scrollTween.TweenProperty(_bottomRoll, "position", _bottomRollOpenPosition, OpenDuration);
		_scrollTween.TweenProperty(_parchmentMask, "position", _maskOpenPosition, OpenDuration);
		_scrollTween.TweenProperty(_parchmentMask, "size", _maskOpenSize, OpenDuration);
		_scrollTween.TweenProperty(_parchment, "position", _parchmentOpenPosition, OpenDuration);
	}

	private bool HasMenuFocus()
	{
		return _resumeButton.HasFocus()
			|| _titleButton.HasFocus()
			|| _quitButton.HasFocus();
	}

	private void ReleaseMenuFocus()
	{
		_resumeButton.ReleaseFocus();
		_titleButton.ReleaseFocus();
		_quitButton.ReleaseFocus();
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
