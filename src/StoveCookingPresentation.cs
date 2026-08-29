using System;
using Godot;

public partial class StoveCookingPresentation : Node
{
    private PickupSocket _socket = null!;
    private OvenCookingController _cookingController = null!;
    private AnimatedSprite2D _frontSprite = null!;
    private PickupItem? _presentedItem;
    private float _elapsed;

    [Export]
    public NodePath SocketPath { get; set; } = new("../PickupSocket");

    [Export]
    public NodePath CookingControllerPath { get; set; } = new("../OvenCookingController");

    [Export]
    public NodePath FrontSpritePath { get; set; } = new("../FrontSprite");

    [Export]
    public Vector2 ItemOffset { get; set; } = new(22.0f, -78.0f);

    [Export(PropertyHint.Range, "0,32,0.1,or_greater")]
    public float BobAmplitude { get; set; } = 4.0f;

    [Export(PropertyHint.Range, "0.1,10,0.1,or_greater")]
    public float BobCyclesPerSecond { get; set; } = 2.0f;

    [Export(PropertyHint.Range, "0,45,0.1,or_greater")]
    public float RotationAmplitudeDegrees { get; set; } = 4.0f;

    public override void _Ready()
    {
        _socket =
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "StoveCookingPresentation requires a valid pickup socket path."
            );
        _cookingController =
            GetNodeOrNull<OvenCookingController>(CookingControllerPath)
            ?? throw new InvalidOperationException(
                "StoveCookingPresentation requires a valid cooking controller path."
            );
        _frontSprite =
            GetNodeOrNull<AnimatedSprite2D>(FrontSpritePath)
            ?? throw new InvalidOperationException(
                "StoveCookingPresentation requires a valid front sprite path."
            );
        _socket.ItemChanged += OnSocketItemChanged;
        SynchronizePresentation();
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
        PickupItem? item = _socket.Item;
        if (!_cookingController.IsCooking || item is null)
        {
            ResetPresentation();
            return;
        }

        if (_presentedItem != item)
        {
            BeginPresentation(item);
        }

        _elapsed += (float)delta;
        float phase = _elapsed * BobCyclesPerSecond * Mathf.Tau;
        item.Position = ItemOffset + Vector2.Down * Mathf.Sin(phase) * BobAmplitude;
        item.Rotation = Mathf.Sin(phase) * RotationAmplitudeDegrees * Mathf.Pi / 180.0f;
    }

    private void OnSocketItemChanged()
    {
        SynchronizePresentation();
    }

    private void SynchronizePresentation()
    {
        PickupItem? item = _socket.Item;
        if (_cookingController.IsCooking && item is not null)
        {
            BeginPresentation(item);
            return;
        }

        ResetPresentation();
    }

    private void BeginPresentation(PickupItem item)
    {
        if (_presentedItem == item)
        {
            return;
        }

        ResetPresentation();
        _presentedItem = item;
        _elapsed = 0.0f;
        item.ResetAttachmentPresentation();
        _frontSprite.Play("cooking");
    }

    private void ResetPresentation()
    {
        if (
            _presentedItem is not null
            && GodotObject.IsInstanceValid(_presentedItem)
            && _presentedItem.GetParent() == _socket
        )
        {
            _presentedItem.ResetAttachmentPresentation();
            _presentedItem.Position = ItemOffset;
        }

        _presentedItem = null;
        _elapsed = 0.0f;
        if (GodotObject.IsInstanceValid(_frontSprite))
        {
            _frontSprite.Play("idle");
        }
    }
}