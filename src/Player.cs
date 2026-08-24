using Godot;

public partial class Player : CharacterBody2D
{
    private static readonly StringName MoveLeftAction = "move_left";
    private static readonly StringName MoveRightAction = "move_right";
    private static readonly StringName MoveUpAction = "move_up";
    private static readonly StringName MoveDownAction = "move_down";

    [Export(PropertyHint.Range, "1,1000,1,or_greater")]
    public float Speed { get; set; } = 240.0f;

    public override void _PhysicsProcess(double delta)
    {
        Vector2 direction = Input.GetVector(
            MoveLeftAction,
            MoveRightAction,
            MoveUpAction,
            MoveDownAction
        );

        Velocity = direction * Speed;
        MoveAndSlide();
    }
}
