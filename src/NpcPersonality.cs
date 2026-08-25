using Godot;
using Godot.Collections;

[GlobalClass]
public partial class NpcPersonality : Resource
{
    [Export(PropertyHint.Range, "0,1,0.01")]
    public float FailureChance { get; set; } = 0.6f;

    [Export]
    public Array<NpcFailureTendency> FailureTendencies { get; set; } = new();

    public float GetFailureWeight(NpcTaskFailureMode mode)
    {
        float weight = 0.0f;
        foreach (NpcFailureTendency? tendency in FailureTendencies)
        {
            if (tendency is not null && tendency.Mode == mode)
            {
                weight += Mathf.Max(0.0f, tendency.Weight);
            }
        }

        return weight;
    }
}
