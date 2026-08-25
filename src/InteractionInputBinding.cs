using Godot;
using Godot.Collections;

public enum InteractionInputTrigger
{
    Tap,
    Hold,
}

[GlobalClass]
public partial class InteractionInputBinding : Resource
{
    [Export]
    public StringName InputAction { get; set; } = "interact";

    [Export]
    public InteractionInputTrigger Trigger { get; set; }

    [Export]
    public Array<StringName> ActionIds { get; set; } = new();
}
