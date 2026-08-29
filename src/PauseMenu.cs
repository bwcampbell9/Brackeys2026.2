using Godot;

public partial class PauseMenu : CanvasLayer
{
	private static readonly StringName PauseAction = "pause";
	private const string TitleScenePath = "res://scenes/title_screen.tscn";

	private Button _resumeButton = null!;
	private bool _isOpen;

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

		_resumeButton.Pressed += CloseMenu;
		titleButton.Pressed += ReturnToTitle;
		quitButton.Pressed += QuitGame;
		Visible = false;
	}

	public override void _UnhandledInput(InputEvent @event)
	{
		if (!@event.IsActionPressed(PauseAction))
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
		if (_isOpen)
		{
			GetTree().Paused = false;
		}
	}

	private void OpenMenu()
	{
		_isOpen = true;
		Visible = true;
		GetTree().Paused = true;
		_resumeButton.GrabFocus();
	}

	private void CloseMenu()
	{
		GetTree().Paused = false;
		_isOpen = false;
		Visible = false;
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
