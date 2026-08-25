using Godot;

[GlobalClass]
public partial class NpcFailureTendency : Resource
{
    [Export]
    public NpcTaskFailureMode Mode { get; set; }

    [Export(PropertyHint.Range, "0,100,0.1,or_greater")]
    public float Weight { get; set; } = 1.0f;
}
