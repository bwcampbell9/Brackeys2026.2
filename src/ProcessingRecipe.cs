using Godot;

[GlobalClass]
public partial class ProcessingRecipe : Resource
{
    [Export]
    public PickupItemDefinition? Input { get; set; }

    [Export]
    public PickupItemDefinition? Output { get; set; }

    [Export]
    public PickupItemDefinition? RequiredTool { get; set; }

    [Export(PropertyHint.Range, "0.1,30,0.1,or_greater")]
    public float Duration { get; set; } = 1.5f;

    public bool Matches(PickupItem item)
    {
        return Input is not null && item.Definition == Input;
    }

    public bool Matches(PickupItem item, PickupItem? tool)
    {
        if (!Matches(item))
        {
            return false;
        }

        return RequiredTool is null
            ? tool is null
            : tool?.Definition == RequiredTool;
    }
}
