using Godot;
using Godot.Collections;

[GlobalClass]
public partial class PickupItemDefinition : Resource
{
    private static readonly StringName IdleAnimation = new("idle");

    [Export]
    public StringName Id { get; set; } = new();

    [Export]
    public string DisplayName { get; set; } = string.Empty;

    [Export]
    public Texture2D? Texture { get; set; }

    [Export]
    public SpriteFrames? SpriteFrames { get; set; }

    [Export]
    public SpriteFrames? ProcessingSpriteFrames { get; set; }

    [Export]
    public Color Modulate { get; set; } = Colors.White;

    [Export]
    public Vector2 VisualScale { get; set; } = Vector2.One;

    [Export]
    public Material? VisualMaterial { get; set; }

    [Export]
    public Array<StringName> AppliedTransformationIds { get; set; } = new();

    [Export]
    public Array<ItemTransformationOverride> TransformationOverrides { get; set; } =
        new();

    public Texture2D? GetDisplayTexture()
    {
        if (Texture is not null)
        {
            return Texture;
        }
        if (
            SpriteFrames is null
            || !SpriteFrames.HasAnimation(IdleAnimation)
            || SpriteFrames.GetFrameCount(IdleAnimation) == 0
        )
        {
            return null;
        }

        return SpriteFrames.GetFrameTexture(IdleAnimation, 0);
    }

    public bool HasAppliedTransformation(StringName transformationId)
    {
        return AppliedTransformationIds.Contains(transformationId);
    }

    public ItemTransformationOverride? FindTransformationOverride(
        StringName transformationId
    )
    {
        foreach (
            ItemTransformationOverride? transformationOverride
            in TransformationOverrides
        )
        {
            if (
                transformationOverride is not null
                && transformationOverride.TransformationId == transformationId
            )
            {
                return transformationOverride;
            }
        }

        return null;
    }
}
