using System;
using Godot;

public partial class OvenCookingController : Node
{
    private PickupSocket _socket = null!;
    private AnimatedSprite2D _sprite = null!;
    private PickupItem? _cookingItem;
    private float _elapsed;

    [Export]
    public NodePath SocketPath { get; set; } = new("../PickupSocket");

    [Export]
    public NodePath SpritePath { get; set; } = new("../AnimatedSprite2D");

    [Export]
    public ProcessingRecipe? Recipe { get; set; }

    public bool IsCooking => _cookingItem is not null;

    public float Progress =>
        IsCooking && Recipe is { Duration: > 0.0f } recipe
            ? Mathf.Clamp(_elapsed / recipe.Duration, 0.0f, 1.0f)
            : 0.0f;

    public override void _Ready()
    {
        _socket =
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "OvenCookingController requires a valid pickup socket path."
            );
        _sprite =
            GetNodeOrNull<AnimatedSprite2D>(SpritePath)
            ?? throw new InvalidOperationException(
                "OvenCookingController requires a valid animated sprite path."
            );
        _socket.ItemChanged += OnSocketItemChanged;
        ResetPresentation();
        BeginCooking(_socket.Item);
    }

    public override void _ExitTree()
    {
        if (GodotObject.IsInstanceValid(_socket))
        {
            _socket.ItemChanged -= OnSocketItemChanged;
        }
    }

    public override void _Process(double delta)
    {
        if (_cookingItem is null)
        {
            return;
        }

        PickupItem? item = _socket.Item;
        ProcessingRecipe? recipe = Recipe;
        if (item != _cookingItem || !CanCook(item, recipe))
        {
            StopCooking();
            return;
        }

        _elapsed += (float)delta;
        if (_elapsed < recipe!.Duration)
        {
            return;
        }

        if (!recipe.Apply(item))
        {
            StopCooking();
            return;
        }

        StopCooking();
    }

    private void OnSocketItemChanged()
    {
        StopCooking();
        BeginCooking(_socket.Item);
    }

    private void BeginCooking(PickupItem? item)
    {
        if (!CanCook(item, Recipe))
        {
            return;
        }

        _cookingItem = item;
        _elapsed = 0.0f;
        _sprite.Play("cooking");
    }

    private static bool CanCook(
        PickupItem? item,
        ProcessingRecipe? recipe
    )
    {
        return item is not null
            && recipe is not null
            && recipe.Duration > 0.0f
            && recipe.Matches(item, null);
    }

    private void StopCooking()
    {
        _cookingItem = null;
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