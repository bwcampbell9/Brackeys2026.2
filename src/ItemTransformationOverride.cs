using Godot;

[GlobalClass]
public partial class ItemTransformationOverride : Resource
{
    [Export]
    public StringName TransformationId { get; set; } = new();

    [Export]
    public PickupItemDefinition? Output { get; set; }
}
