using System;
using Godot;

[GlobalClass]
public partial class ItemTransformation : Resource
{
    [Export]
    public StringName Id { get; set; } = new();

    [Export]
    public string ResultIdPrefix { get; set; } = string.Empty;

    [Export]
    public string ResultNamePrefix { get; set; } = string.Empty;

    [Export]
    public Material? FallbackMaterial { get; set; }

    [Export]
    public PickupItemDefinition? FallbackOutput { get; set; }

    public bool CanApply(PickupItemDefinition input)
    {
        if (Id.IsEmpty || input.HasAppliedTransformation(Id))
        {
            return false;
        }

        ItemTransformationOverride? transformationOverride =
            input.FindTransformationOverride(Id);
        return transformationOverride?.Output is not null
            || FallbackOutput is not null
            || FallbackMaterial is not null;
    }

    public PickupItemDefinition Resolve(PickupItemDefinition input)
    {
        if (!CanApply(input))
        {
            throw new InvalidOperationException(
                $"{Id} cannot be applied to {input.Id}."
            );
        }

        PickupItemDefinition? explicitOutput =
            input.FindTransformationOverride(Id)?.Output;
        bool usesGeneratedFallback = explicitOutput is null
            && FallbackOutput is null;
        PickupItemDefinition outputTemplate;
        if (explicitOutput is not null)
        {
            outputTemplate = explicitOutput;
        }
        else if (FallbackOutput is not null)
        {
            outputTemplate = FallbackOutput;
        }
        else
        {
            if (FallbackMaterial is null)
            {
                throw new InvalidOperationException(
                    $"{Id} requires a fallback output or material."
                );
            }

            outputTemplate = input;
        }

        string idPrefix = string.IsNullOrWhiteSpace(ResultIdPrefix)
            ? Id.ToString()
            : ResultIdPrefix;
        var result = new PickupItemDefinition
        {
            Id = usesGeneratedFallback
                ? $"{idPrefix}_{input.Id}"
                : outputTemplate.Id,
            DisplayName = usesGeneratedFallback
                ? $"{ResultNamePrefix}{input.DisplayName}"
                : outputTemplate.DisplayName,
            Texture = outputTemplate.Texture,
            SpriteFrames = outputTemplate.SpriteFrames,
            Modulate = outputTemplate.Modulate,
            VisualScale = outputTemplate.VisualScale,
            VisualMaterial = usesGeneratedFallback
                ? FallbackMaterial
                : outputTemplate.VisualMaterial,
        };

        CopyTransformationIds(outputTemplate, result);
        CopyTransformationIds(input, result);
        AddTransformationId(result, Id);
        foreach (
            ItemTransformationOverride? transformationOverride
            in outputTemplate.TransformationOverrides
        )
        {
            if (transformationOverride is not null)
            {
                result.TransformationOverrides.Add(transformationOverride);
            }
        }

        return result;
    }

    private static void CopyTransformationIds(
        PickupItemDefinition source,
        PickupItemDefinition destination
    )
    {
        foreach (StringName transformationId in source.AppliedTransformationIds)
        {
            AddTransformationId(destination, transformationId);
        }
    }

    private static void AddTransformationId(
        PickupItemDefinition definition,
        StringName transformationId
    )
    {
        if (!definition.AppliedTransformationIds.Contains(transformationId))
        {
            definition.AppliedTransformationIds.Add(transformationId);
        }
    }
}
