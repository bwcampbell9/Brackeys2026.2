using Godot;

[GlobalClass]
public partial class PickupItemDefinition : Resource
{
    [Export]
    public StringName Id { get; set; } = new();

    [Export]
    public string DisplayName { get; set; } = string.Empty;

    [Export]
    public Texture2D? Texture { get; set; }

    [Export]
    public Color Modulate { get; set; } = Colors.White;

    [Export]
    public Vector2 VisualScale { get; set; } = Vector2.One;
}
