using System;
using System.Collections.Generic;
using Godot;
using Godot.Collections;

public partial class OvenCookingController : Node
{
    private readonly List<PickupSocket> _sockets = new();
    private readonly List<PickupItem> _cookingItems = new();
    private AnimatedSprite2D _sprite = null!;
    private CookingRecipe? _selectedCookingRecipe;
    private float _elapsed;
    private bool _isApplyingRecipe;

    [Signal]
    public delegate void CookingStateChangedEventHandler();

    [Signal]
    public delegate void CookingCompletedEventHandler(
        PickupItemDefinition output
    );

    [Export]
    public NodePath SocketPath { get; set; } = new("../PickupSocket");

    [Export]
    public Array<NodePath> AdditionalSocketPaths { get; set; } = new();

    [Export]
    public NodePath SpritePath { get; set; } = new("../AnimatedSprite2D");

    [Export]
    public ProcessingRecipe? Recipe { get; set; }

    [Export]
    public Array<CookingRecipe> Recipes { get; set; } = new();

    [Export]
    public CookingRecipe? SelectedCookingRecipe
    {
        get => _selectedCookingRecipe;
        set
        {
            if (_selectedCookingRecipe == value)
            {
                return;
            }

            _selectedCookingRecipe = value;
            if (IsNodeReady())
            {
                ReconcileCooking();
                EmitSignal(SignalName.CookingStateChanged);
            }
        }
    }

    public bool IsCooking => _cookingItems.Count > 0;

    public bool HasAnyItem
    {
        get
        {
            foreach (PickupSocket socket in _sockets)
            {
                if (socket.Item is not null)
                {
                    return true;
                }
            }
            return false;
        }
    }

    public float Progress
    {
        get
        {
            float duration = GetActiveDuration();
            return IsCooking && duration > 0.0f
                ? Mathf.Clamp(_elapsed / duration, 0.0f, 1.0f)
                : 0.0f;
        }
    }

    public override void _Ready()
    {
        AddSocket(
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "OvenCookingController requires a valid pickup socket path."
            )
        );
        foreach (NodePath path in AdditionalSocketPaths)
        {
            AddSocket(
                GetNodeOrNull<PickupSocket>(path)
                ?? throw new InvalidOperationException(
                    $"OvenCookingController requires pickup socket '{path}'."
                )
            );
        }

        _sprite =
            GetNodeOrNull<AnimatedSprite2D>(SpritePath)
            ?? throw new InvalidOperationException(
                "OvenCookingController requires a valid animated sprite path."
            );
        if (Recipes.Count > 0 && _selectedCookingRecipe is null)
        {
            _selectedCookingRecipe = Recipes[0];
        }

        ResetPresentation();
        BeginCooking();
    }

    public override void _ExitTree()
    {
        foreach (PickupSocket socket in _sockets)
        {
            if (GodotObject.IsInstanceValid(socket))
            {
                socket.ItemChanged -= OnSocketItemChanged;
            }
        }
    }

    public override void _Process(double delta)
    {
        if (!IsCooking)
        {
            return;
        }

        if (!CookingItemsAreUnchanged() || !CanCookStoredItems())
        {
            StopCooking();
            return;
        }

        _elapsed += (float)delta;
        if (_elapsed < GetActiveDuration())
        {
            return;
        }

        if (!ApplyActiveRecipe())
        {
            StopCooking();
            return;
        }

        StopCooking();
        EmitSignal(SignalName.CookingStateChanged);
    }

    public bool CanAccept(PickupItem item)
    {
        if (item.Definition is not PickupItemDefinition definition)
        {
            return false;
        }

        List<PickupItem> storedItems = GetStoredItems();
        if (UsesAuthoredRecipes)
        {
            return _selectedCookingRecipe is not null
                && _selectedCookingRecipe.CanAccept(
                    storedItems,
                    definition
                );
        }

        return storedItems.Count == 0
            && Recipe is not null
            && Recipe.Matches(item, null);
    }

    public CookingRecipe? FindRecipeByOutput(
        PickupItemDefinition output
    )
    {
        foreach (CookingRecipe recipe in Recipes)
        {
            if (recipe.Output?.Id == output.Id)
            {
                return recipe;
            }
        }
        return null;
    }

    public bool TrySelectRecipe(CookingRecipe recipe)
    {
        if (HasAnyItem || !Recipes.Contains(recipe))
        {
            return false;
        }

        SelectedCookingRecipe = recipe;
        return true;
    }

    public PickupItemDefinition? GetFirstMissingIngredient()
    {
        return _selectedCookingRecipe?.GetFirstMissingIngredient(
            GetStoredItems()
        );
    }

    private bool UsesAuthoredRecipes => Recipes.Count > 0;

    private void AddSocket(PickupSocket socket)
    {
        _sockets.Add(socket);
        socket.ItemChanged += OnSocketItemChanged;
    }

    private List<PickupItem> GetStoredItems()
    {
        var items = new List<PickupItem>();
        foreach (PickupSocket socket in _sockets)
        {
            if (socket.Item is PickupItem item)
            {
                items.Add(item);
            }
        }
        return items;
    }

    private void OnSocketItemChanged()
    {
        if (_isApplyingRecipe)
        {
            return;
        }

        ReconcileCooking();
        EmitSignal(SignalName.CookingStateChanged);
    }

    private void ReconcileCooking()
    {
        StopCooking();
        BeginCooking();
    }

    private void BeginCooking()
    {
        if (!CanCookStoredItems())
        {
            return;
        }

        _cookingItems.AddRange(GetStoredItems());
        _elapsed = 0.0f;
        _sprite.Play("cooking");
    }

    private bool CanCookStoredItems()
    {
        List<PickupItem> items = GetStoredItems();
        if (UsesAuthoredRecipes)
        {
            return _selectedCookingRecipe is { Duration: > 0.0f } recipe
                && recipe.Matches(items);
        }

        return items.Count == 1
            && Recipe is { Duration: > 0.0f } legacyRecipe
            && legacyRecipe.Matches(items[0], null);
    }

    private bool CookingItemsAreUnchanged()
    {
        List<PickupItem> storedItems = GetStoredItems();
        if (storedItems.Count != _cookingItems.Count)
        {
            return false;
        }

        for (int index = 0; index < storedItems.Count; index++)
        {
            if (storedItems[index] != _cookingItems[index])
            {
                return false;
            }
        }
        return true;
    }

    private float GetActiveDuration()
    {
        return UsesAuthoredRecipes
            ? _selectedCookingRecipe?.Duration ?? 0.0f
            : Recipe?.Duration ?? 0.0f;
    }

    private bool ApplyActiveRecipe()
    {
        if (UsesAuthoredRecipes)
        {
            return ApplyAuthoredRecipe();
        }

        return _cookingItems.Count == 1
            && Recipe is not null
            && Recipe.Apply(_cookingItems[0]);
    }

    private bool ApplyAuthoredRecipe()
    {
        CookingRecipe? recipe = _selectedCookingRecipe;
        if (
            recipe?.Output is not PickupItemDefinition output
            || !recipe.Matches(_cookingItems)
        )
        {
            return false;
        }

        _isApplyingRecipe = true;
        try
        {
            PickupItem resultItem = _cookingItems[0];
            resultItem.SetDefinition(output);
            for (int index = 1; index < _cookingItems.Count; index++)
            {
                PickupItem consumedItem = _cookingItems[index];
                foreach (PickupSocket socket in _sockets)
                {
                    if (socket.Item == consumedItem)
                    {
                        socket.TryDiscard(consumedItem);
                        break;
                    }
                }
            }
            EmitSignal(SignalName.CookingCompleted, output);
            return true;
        }
        finally
        {
            _isApplyingRecipe = false;
        }
    }

    private void StopCooking()
    {
        _cookingItems.Clear();
        _elapsed = 0.0f;
        ResetPresentation();
    }

    private void ResetPresentation()
    {
        if (GodotObject.IsInstanceValid(_sprite))
        {
            _sprite.Play("idle");
        }
    }
}
