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

    public bool CanApply(PickupItemDefinition input)
    {
        if (Id.IsEmpty || input.HasAppliedTransformation(Id))
        {
            return false;
        }

        ItemTransformationOverride? transformationOverride =
            input.FindTransformationOverride(Id);
        return transformationOverride?.Output is not null
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
        bool usesFallback = explicitOutput is null;
        PickupItemDefinition outputTemplate;
        if (explicitOutput is null)
        {
            if (FallbackMaterial is null)
            {
                throw new InvalidOperationException(
                    $"{Id} requires a fallback material."
                );
            }

            outputTemplate = input;
        }
        else
        {
            outputTemplate = explicitOutput;
        }

        string idPrefix = string.IsNullOrWhiteSpace(ResultIdPrefix)
            ? Id.ToString()
            : ResultIdPrefix;
        var result = new PickupItemDefinition
        {
            Id = usesFallback
                ? $"{idPrefix}_{input.Id}"
                : outputTemplate.Id,
            DisplayName = usesFallback
                ? $"{ResultNamePrefix}{input.DisplayName}"
                : outputTemplate.DisplayName,
            Texture = outputTemplate.Texture,
            Modulate = outputTemplate.Modulate,
            VisualScale = outputTemplate.VisualScale,
            VisualMaterial = usesFallback
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
