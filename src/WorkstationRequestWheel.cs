using Godot;
using Godot.Collections;

public partial class WorkstationRequestWheel : Control
{
    private static readonly Color BlueTint = new(0.4f, 0.7f, 1.0f, 1.0f);
    private Array<PickupItemDefinition> _items = new();
    private int _selectedIndex;
    private Vector2 _center;

    public PickupItemDefinition? SelectedItem =>
        _items.Count == 0 ? null : _items[_selectedIndex];

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        SetProcess(false);
        Hide();
    }

    public void Open(
        Array<PickupItemDefinition> items,
        PickupItemDefinition? currentItem,
        Vector2 center
    )
    {
        _items = items;
        _selectedIndex = FindSelectedIndex(currentItem);
        SetCenter(center);
        SetProcess(true);
        Show();
        QueueRedraw();
    }

    public void Close()
    {
        SetProcess(false);
        Hide();
    }

    public void SetCenter(Vector2 center)
    {
        _center = center;
        Size = GetViewportRect().Size;
        Position = Vector2.Zero;
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
        UpdateSelection(GetGlobalMousePosition() - _center);
    }

    private void UpdateSelection(Vector2 direction)
    {
        if (_items.Count < 2 || direction.LengthSquared() < 64.0f)
        {
            return;
        }

        float angle = Mathf.Atan2(direction.Y, direction.X) + Mathf.Pi * 0.5f;
        if (angle < 0.0f)
        {
            angle += Mathf.Tau;
        }

        int index = Mathf.PosMod(
            Mathf.FloorToInt(angle / Mathf.Tau * _items.Count + 0.5f),
            _items.Count
        );
        if (_selectedIndex == index)
        {
            return;
        }

        _selectedIndex = index;
        QueueRedraw();
    }

    private int FindSelectedIndex(PickupItemDefinition? currentItem)
    {
        if (currentItem is not null)
        {
            for (int index = 0; index < _items.Count; index++)
            {
                if (_items[index].Id == currentItem.Id)
                {
                    return index;
                }
            }
        }

        return 0;
    }

    public override void _Draw()
    {
        if (_items.Count == 0)
        {
            return;
        }

        DrawCircle(_center, 92.0f, new Color(0.04f, 0.08f, 0.14f, 0.94f));
        DrawArc(_center, 92.0f, 0.0f, Mathf.Tau, 64, BlueTint, 3.0f);
        float step = Mathf.Tau / _items.Count;
        for (int index = 0; index < _items.Count; index++)
        {
            float angle = -Mathf.Pi * 0.5f + index * step;
            Vector2 itemCenter = _center + Vector2.FromAngle(angle) * 58.0f;
            bool selected = index == _selectedIndex;
            float radius = selected ? 27.0f : 22.0f;
            DrawCircle(
                itemCenter,
                radius,
                selected
                    ? new Color(0.12f, 0.3f, 0.52f, 1.0f)
                    : new Color(0.1f, 0.14f, 0.2f, 1.0f)
            );
            DrawArc(itemCenter, radius, 0.0f, Mathf.Tau, 32, selected ? BlueTint : Colors.White, 2.0f);
            PickupItemDefinition item = _items[index];
            if (item.Texture is not null)
            {
                Vector2 size = item.Texture.GetSize() * item.VisualScale * 0.55f;
                DrawTextureRect(
                    item.Texture,
                    new Rect2(itemCenter - size * 0.5f, size),
                    false,
                    item.Modulate
                );
            }
        }
    }
}