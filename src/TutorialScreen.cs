using Godot;

public partial class TutorialScreen : Control
{
    private const string TitleScenePath = "res://scenes/title_screen.tscn";
    private static readonly StringName AcceptAction = "ui_accept";
    private static readonly StringName CancelAction = "ui_cancel";

    private bool _isLeaving;

    public override void _UnhandledInput(InputEvent @event)
    {
        if (
            _isLeaving
            || (!@event.IsActionPressed(AcceptAction) && !@event.IsActionPressed(CancelAction))
        )
        {
            return;
        }

        _isLeaving = true;
        GetTree().ChangeSceneToFile(TitleScenePath);
        GetViewport().SetInputAsHandled();
    }
}