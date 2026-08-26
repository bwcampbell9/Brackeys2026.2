using Godot;

public partial class TitleScreen : Control
{
    private const string MainScenePath = "res://scenes/main.tscn";
    private Button _playButton = null!;
    private Button _exitButton = null!;

    public override void _Ready()
    {
        _playButton = GetNode<Button>("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayButton");
        _exitButton = GetNode<Button>("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ExitButton");

        _playButton.Pressed += OnPlayPressed;
        _exitButton.Pressed += OnExitPressed;
        _playButton.GrabFocus();
    }

    private void OnPlayPressed()
    {
        GetTree().ChangeSceneToFile(MainScenePath);
    }

    private void OnExitPressed()
    {
        GetTree().Quit();
    }
}