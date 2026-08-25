using Godot;

[GlobalClass]
public partial class ProcessingRecipe : Resource
{
    [Export]
    public ItemTransformation? Transformation { get; set; }

    [Export]
    public PickupItemDefinition? RequiredTool { get; set; }

    [Export(PropertyHint.Range, "0.1,30,0.1,or_greater")]
    public float Duration { get; set; } = 1.5f;

    public bool Matches(PickupItem item)
    {
        return Transformation is not null
            && item.Definition is PickupItemDefinition definition
            && Transformation.CanApply(definition);
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

    public bool Apply(PickupItem item)
    {
        if (
            Transformation is null
            || item.Definition is not PickupItemDefinition definition
            || !Transformation.CanApply(definition)
        )
        {
            return false;
        }

        item.SetDefinition(Transformation.Resolve(definition));
        return true;
    }
}
