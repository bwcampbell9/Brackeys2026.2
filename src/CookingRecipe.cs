using System.Collections.Generic;
using Godot;
using Godot.Collections;

[GlobalClass]
public partial class CookingRecipe : Resource
{
    [Export]
    public PickupItemDefinition? Output { get; set; }

    [Export]
    public Array<PickupItemDefinition> Ingredients { get; set; } = new();

    [Export(PropertyHint.Range, "0.1,30,0.1,or_greater")]
    public float Duration { get; set; } = 10.0f;

    public bool Matches(IReadOnlyList<PickupItem> items)
    {
        if (
            Output is null
            || Ingredients.Count == 0
            || items.Count != Ingredients.Count
        )
        {
            return false;
        }

        foreach (PickupItemDefinition ingredient in Ingredients)
        {
            int requiredCount = CountRequired(ingredient.Id);
            int storedCount = CountStored(items, ingredient.Id);
            if (storedCount != requiredCount)
            {
                return false;
            }
        }

        return true;
    }

    public bool CanAccept(
        IReadOnlyList<PickupItem> storedItems,
        PickupItemDefinition candidate
    )
    {
        return IsValidPartial(storedItems)
            && storedItems.Count < Ingredients.Count
            && CountStored(storedItems, candidate.Id)
                < CountRequired(candidate.Id);
    }

    public PickupItemDefinition? GetFirstMissingIngredient(
        IReadOnlyList<PickupItem> storedItems
    )
    {
        if (!IsValidPartial(storedItems))
        {
            return null;
        }

        foreach (PickupItemDefinition ingredient in Ingredients)
        {
            if (
                CountStored(storedItems, ingredient.Id)
                < CountRequired(ingredient.Id)
            )
            {
                return ingredient;
            }
        }

        return null;
    }

    private bool IsValidPartial(IReadOnlyList<PickupItem> items)
    {
        if (items.Count > Ingredients.Count)
        {
            return false;
        }

        foreach (PickupItem item in items)
        {
            if (
                item.Definition is not PickupItemDefinition definition
                || CountRequired(definition.Id) == 0
                || CountStored(items, definition.Id)
                    > CountRequired(definition.Id)
            )
            {
                return false;
            }
        }

        return true;
    }

    private int CountRequired(StringName id)
    {
        int count = 0;
        foreach (PickupItemDefinition ingredient in Ingredients)
        {
            if (ingredient.Id == id)
            {
                count++;
            }
        }
        return count;
    }

    private static int CountStored(
        IReadOnlyList<PickupItem> items,
        StringName id
    )
    {
        int count = 0;
        foreach (PickupItem item in items)
        {
            if (item.Definition?.Id == id)
            {
                count++;
            }
        }
        return count;
    }
}
