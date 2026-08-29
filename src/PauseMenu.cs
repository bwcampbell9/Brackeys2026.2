using Godot;

public partial class PauseMenu : CanvasLayer
{
	private static readonly StringName PauseAction = "pause";
	private static readonly StringName CancelAction = "ui_cancel";
	private static readonly StringName AcceptAction = "ui_accept";
	private const string TitleScenePath = "res://scenes/title_screen.tscn";

	private Button _resumeButton = null!;
	private PlayerInputManager _playerInputManager = null!;
	private bool _isOpen;
	private bool _resumePending;
	private bool _blockingActionReleaseObserved;
	private StringName _resumeBlockingAction = "";

	[Export]
	public NodePath PlayerInputManagerPath { get; set; } = "../Player/InputManager";

	public override void _Ready()
	{
		ProcessMode = ProcessModeEnum.Always;
		_playerInputManager = GetNode<PlayerInputManager>(PlayerInputManagerPath);
		_resumeButton = GetNode<Button>(
			"Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton"
		);
		Button titleButton = GetNode<Button>(
			"Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleButton"
		);
		Button quitButton = GetNode<Button>(
			"Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton"
		);

		_resumeButton.Pressed += ResumeFromSelection;
		titleButton.Pressed += ReturnToTitle;
		quitButton.Pressed += QuitGame;
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

	public override void _UnhandledInput(InputEvent @event)
	{
		bool pausePressed = @event.IsActionPressed(PauseAction);
		bool cancelPressed = _isOpen && @event.IsActionPressed(CancelAction);
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
		_resumeButton.GrabFocus();
	}

	private void CloseMenu()
	{
		_resumePending = false;
		_blockingActionReleaseObserved = false;
		_resumeBlockingAction = "";
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
		_isOpen = false;
		Visible = false;
		_resumePending = true;
		_blockingActionReleaseObserved = false;
		_resumeBlockingAction = blockingAction;
	}

	private void ReturnToTitle()
	{
		GetTree().Paused = false;
		_isOpen = false;
		GetTree().ChangeSceneToFile(TitleScenePath);
	}

	private void QuitGame()
	{
		GetTree().Quit();
	}
}
