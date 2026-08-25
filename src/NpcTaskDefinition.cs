using Godot;
using Godot.Collections;

public enum NpcTaskKind
{
    Fetch,
    Action,
}

[GlobalClass]
public partial class NpcTaskDefinition : Resource
{
    [Export]
    public StringName Id { get; set; } = new();

    [Export]
    public NpcTaskKind Kind { get; set; }

    [Export]
    public Array<StringName> RequiredTags { get; set; } = new();

    [Export]
    public Array<NpcTaskFailureOption> FailureOptions { get; set; } = new();

    [Export]
    public int Priority { get; set; }
}
