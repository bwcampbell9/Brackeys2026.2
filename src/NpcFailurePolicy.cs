using System;
using Godot;

public static class NpcFailurePolicy
{
    public static NpcTaskFailureMode? Select(
        NpcTaskDefinition task,
        NpcPersonality? personality,
        RandomNumberGenerator random,
        Func<NpcTaskFailureMode, bool> isFeasible
    )
    {
        ArgumentNullException.ThrowIfNull(task);
        ArgumentNullException.ThrowIfNull(random);
        ArgumentNullException.ThrowIfNull(isFeasible);

        if (
            personality is null
            || personality.FailureChance <= 0.0f
            || random.Randf() >= personality.FailureChance
        )
        {
            return null;
        }

        float totalWeight = 0.0f;
        foreach (NpcTaskFailureOption? option in task.FailureOptions)
        {
            if (
                option is null
                || !isFeasible(option.Mode)
            )
            {
                continue;
            }

            totalWeight += GetCombinedWeight(option, personality);
        }

        if (totalWeight <= 0.0f)
        {
            return null;
        }

        float selection = random.RandfRange(0.0f, totalWeight);
        foreach (NpcTaskFailureOption? option in task.FailureOptions)
        {
            if (
                option is null
                || !isFeasible(option.Mode)
            )
            {
                continue;
            }

            selection -= GetCombinedWeight(option, personality);
            if (selection <= 0.0f)
            {
                return option.Mode;
            }
        }

        return null;
    }

    private static float GetCombinedWeight(
        NpcTaskFailureOption option,
        NpcPersonality personality
    )
    {
        return Mathf.Max(0.0f, option.WeightMultiplier)
            * personality.GetFailureWeight(option.Mode);
    }
}
