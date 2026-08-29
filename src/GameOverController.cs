using Godot;

public partial class GameOverController : CanvasLayer
{
    private static readonly StringName GameOverAction = "game_over";
    private static readonly StringName FocusUvParameter = "focus_uv";
    private static readonly StringName ProgressParameter = "progress";

    private Node2D _player = null!;
    private ColorRect _overlay = null!;
    private ShaderMaterial _overlayMaterial = null!;
    private double _elapsed;
    private bool _isGameOver;

    [Export]
    public NodePath PlayerPath { get; set; } = "../Player";

    [Export(PropertyHint.Range, "0.1,5,0.1,or_greater")]
    public float RevealDuration { get; set; } = 0.75f;

    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
        _player = GetNode<Node2D>(PlayerPath);

        _overlayMaterial = new ShaderMaterial
        {
            Shader = GD.Load<Shader>("res://assets/shaders/game_over.gdshader"),
        };
        _overlay = new ColorRect
        {
            Material = _overlayMaterial,
            MouseFilter = Control.MouseFilterEnum.Ignore,
            Visible = false,
        };
        _overlay.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        AddChild(_overlay);
    }

    public override void _Process(double delta)
    {
        if (Input.IsActionJustPressed(GameOverAction))
        {
            if (_isGameOver)
            {
                RestartScene();
            }
            else
            {
                BeginGameOver();
            }
        }

        if (!_isGameOver)
        {
            return;
        }

        _elapsed += delta;
        float progress = Mathf.Clamp((float)(_elapsed / RevealDuration), 0.0f, 1.0f);
        Vector2 viewportSize = GetViewport().GetVisibleRect().Size;
        Vector2 focusUv = _player.GlobalPosition / viewportSize;
        _overlayMaterial.SetShaderParameter(FocusUvParameter, focusUv);
        _overlayMaterial.SetShaderParameter(ProgressParameter, progress);
    }

    private void BeginGameOver()
    {
        _isGameOver = true;
        _elapsed = 0.0;
        _overlay.Visible = true;
        GetTree().Paused = true;
    }

    private void RestartScene()
    {
        GetTree().Paused = false;
        GetTree().ReloadCurrentScene();
    }
}