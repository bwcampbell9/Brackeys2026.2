using Godot;

public partial class PauseMenu : CanvasLayer
{
	private static readonly StringName PauseAction = "pause";
	private static readonly StringName CancelAction = "ui_cancel";
	private static readonly StringName AcceptAction = "ui_accept";
	private const string TitleScenePath = "res://scenes/title_screen.tscn";

	private Button _resumeButton = null!;
	private bool _isOpen;
	private bool _resumePending;
	private bool _acceptReleaseObserved;

	public override void _Ready()
	{
		ProcessMode = ProcessModeEnum.Always;
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

		if (Input.IsActionPressed(AcceptAction))
		{
			_acceptReleaseObserved = false;
			return;
		}

		if (!_acceptReleaseObserved)
		{
			_acceptReleaseObserved = true;
			return;
		}

		_resumePending = false;
		_acceptReleaseObserved = false;
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
			CloseMenu();
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
		_acceptReleaseObserved = false;
		_isOpen = true;
		Visible = true;
		GetTree().Paused = true;
		_resumeButton.GrabFocus();
	}

	private void CloseMenu()
	{
		_resumePending = false;
		_acceptReleaseObserved = false;
		GetTree().Paused = false;
		_isOpen = false;
		Visible = false;
	}

	private void ResumeFromSelection()
	{
		_isOpen = false;
		Visible = false;
		_resumePending = true;
		_acceptReleaseObserved = false;
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
