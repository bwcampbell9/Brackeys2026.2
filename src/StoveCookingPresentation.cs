using System;
using System.Collections.Generic;
using Godot;
using Godot.Collections;

public partial class StoveCookingPresentation : Node
{
    private readonly List<PickupSocket> _sockets = new();
    private readonly List<PickupItem> _presentedItems = new();
    private OvenCookingController _cookingController = null!;
    private AnimatedSprite2D _frontSprite = null!;
    private float _elapsed;

    [Export]
    public NodePath SocketPath { get; set; } = new("../PickupSocket");

    [Export]
    public Array<NodePath> AdditionalSocketPaths { get; set; } = new();

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
        AddSocket(
            GetNodeOrNull<PickupSocket>(SocketPath)
            ?? throw new InvalidOperationException(
                "StoveCookingPresentation requires a valid pickup socket path."
            )
        );
        foreach (NodePath path in AdditionalSocketPaths)
        {
            AddSocket(
                GetNodeOrNull<PickupSocket>(path)
                ?? throw new InvalidOperationException(
                    $"StoveCookingPresentation requires pickup socket '{path}'."
                )
            );
        }
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
        SynchronizePresentation();
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
        List<PickupItem> items = GetStoredItems();
        if (!_cookingController.IsCooking || items.Count == 0)
        {
            ResetPresentation();
            return;
        }

        if (!PresentationMatches(items))
        {
            BeginPresentation(items);
        }

        _elapsed += (float)delta;
        float phase = _elapsed * BobCyclesPerSecond * Mathf.Tau;
        for (int index = 0; index < _presentedItems.Count; index++)
        {
            PickupItem item = _presentedItems[index];
            float itemPhase = phase + index * 0.35f;
            item.Position =
                ItemOffset
                + Vector2.Down * Mathf.Sin(itemPhase) * BobAmplitude;
            item.Rotation =
                Mathf.Sin(itemPhase)
                * RotationAmplitudeDegrees
                * Mathf.Pi
                / 180.0f;
        }
    }

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
        SynchronizePresentation();
    }

    private void SynchronizePresentation()
    {
        List<PickupItem> items = GetStoredItems();
        if (_cookingController.IsCooking && items.Count > 0)
        {
            BeginPresentation(items);
            return;
        }

        ResetPresentation();
    }

    private bool PresentationMatches(List<PickupItem> items)
    {
        if (_presentedItems.Count != items.Count)
        {
            return false;
        }

        for (int index = 0; index < items.Count; index++)
        {
            if (_presentedItems[index] != items[index])
            {
                return false;
            }
        }
        return true;
    }

    private void BeginPresentation(List<PickupItem> items)
    {
        ResetPresentation();
        _presentedItems.AddRange(items);
        _elapsed = 0.0f;
        foreach (PickupItem item in _presentedItems)
        {
            item.ResetAttachmentPresentation();
        }
        _frontSprite.Play("cooking");
    }

    private void ResetPresentation()
    {
        foreach (PickupItem item in _presentedItems)
        {
            if (
                !GodotObject.IsInstanceValid(item)
                || item.GetParent() is not PickupSocket socket
                || !_sockets.Contains(socket)
            )
            {
                continue;
            }

            item.ResetAttachmentPresentation();
            item.Position = ItemOffset;
        }

        _presentedItems.Clear();
        _elapsed = 0.0f;
        if (GodotObject.IsInstanceValid(_frontSprite))
        {
            _frontSprite.Play("idle");
        }
    }
}