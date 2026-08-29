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
    public ItemTransformation? Transformation { get; set; }

    [Export(PropertyHint.Range, "0.1,300,0.1,or_greater")]
    public float CookDuration { get; set; } = 10.0f;

    public bool IsCooking => _cookingItem is not null;

    public float Progress => IsCooking
        ? Mathf.Clamp(_elapsed / CookDuration, 0.0f, 1.0f)
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
        if (item != _cookingItem || !CanCook(item))
        {
            StopCooking();
            return;
        }

        _elapsed += (float)delta;
        if (_elapsed < CookDuration)
        {
            return;
        }

        if (Transformation!.Resolve(item.Definition!) is PickupItemDefinition output)
        {
            item.SetDefinition(output);
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
        if (!CanCook(item))
        {
            return;
        }

        _cookingItem = item;
        _elapsed = 0.0f;
        _sprite.Play("cooking");
    }

    private bool CanCook(PickupItem? item)
    {
        return item?.Definition is PickupItemDefinition definition
            && Transformation is not null
            && Transformation.CanApply(definition)
            && CookDuration > 0.0f;
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