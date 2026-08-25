using Godot;

public enum NpcTaskFailureMode
{
    WrongFetchedItem,
}

[GlobalClass]
public partial class NpcTaskFailureOption : Resource
{
    [Export]
    public NpcTaskFailureMode Mode { get; set; }

    [Export(PropertyHint.Range, "0,100,0.1,or_greater")]
    public float WeightMultiplier { get; set; } = 1.0f;
}
