using System.Collections.Generic;
using Godot;
using Godot.Collections;

public partial class WorkstationRequestWheel : Control
{
    private sealed class WheelEntry
    {
        public WheelEntry(
            List<PickupItemDefinition> ingredients,
            CookingRecipe? recipe = null
        )
        {
            Ingredients = ingredients;
            Recipe = recipe;
        }

        public List<PickupItemDefinition> Ingredients { get; }

        public CookingRecipe? Recipe { get; }
    }

    private static readonly StringName WheelLeftAction = "move_left";
    private static readonly StringName WheelRightAction = "move_right";
    private static readonly StringName WheelUpAction = "move_up";
    private static readonly StringName WheelDownAction = "move_down";
    private static readonly StringName PreviousPageAction =
        "recipe_wheel_previous_page";
    private static readonly StringName NextPageAction =
        "recipe_wheel_next_page";
    private static readonly Color BlueTint = new(0.4f, 0.7f, 1.0f, 1.0f);
    private const int ItemsPerPage = 12;
    private const float DesiredItemRadius = 22.0f;
    private const float MinimumItemRadius = 8.0f;
    private const float MinimumOrbitRadius = 58.0f;
    private const float ItemGap = 8.0f;
    private const float WheelPadding = 16.0f;
    private const float MouseDeadzoneSquared = 64.0f;
    private readonly List<WheelEntry> _entries = new();
    private int _selectedIndex;
    private Vector2 _requestedCenter;
    private Vector2 _drawCenter;
    private Vector2 _viewportSize;
    private float _orbitRadius;
    private float _itemRadius;
    private float _backgroundRadius;
    private int _pageIndex;
    private bool _controllerSelectionActive;

    public PickupItemDefinition? SelectedItem =>
        _entries.Count == 0 ? null : _entries[_selectedIndex].Ingredients[0];

    public CookingRecipe? SelectedRecipe =>
        _entries.Count == 0 ? null : _entries[_selectedIndex].Recipe;

    public int PageCount =>
        Mathf.CeilToInt((float)_entries.Count / ItemsPerPage);

    public int CurrentPageIndex => _pageIndex;

    public int EntryCount => _entries.Count;

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
        _entries.Clear();
        foreach (PickupItemDefinition item in items)
        {
            if (item is not null)
            {
                _entries.Add(
                    new WheelEntry(new List<PickupItemDefinition> { item })
                );
            }
        }

        _selectedIndex = FindSelectedIndex(currentItem);
        _pageIndex = _selectedIndex / ItemsPerPage;
        _controllerSelectionActive = false;
        SetCenter(center);
        SetProcess(true);
        Show();
        QueueRedraw();
    }

    public void OpenRecipes(
        Array<CookingRecipe> recipes,
        CookingRecipe? currentRecipe,
        Vector2 center
    )
    {
        _entries.Clear();
        foreach (CookingRecipe recipe in recipes)
        {
            if (recipe is null || recipe.Ingredients.Count == 0)
            {
                continue;
            }

            var ingredients = new List<PickupItemDefinition>();
            foreach (PickupItemDefinition ingredient in recipe.Ingredients)
            {
                if (ingredient is not null)
                {
                    ingredients.Add(ingredient);
                }
            }
            if (ingredients.Count > 0)
            {
                _entries.Add(new WheelEntry(ingredients, recipe));
            }
        }

        _selectedIndex = FindSelectedRecipeIndex(currentRecipe);
        _pageIndex = _selectedIndex / ItemsPerPage;
        _controllerSelectionActive = false;
        SetCenter(center);
        SetProcess(true);
        Show();
        QueueRedraw();
    }

    public int GetSelectedIngredientCount()
    {
        return _entries.Count == 0
            ? 0
            : _entries[_selectedIndex].Ingredients.Count;
    }

    public PickupItemDefinition? GetSelectedIngredient(int index)
    {
        if (
            _entries.Count == 0
            || index < 0
            || index >= _entries[_selectedIndex].Ingredients.Count
        )
        {
            return null;
        }

        return _entries[_selectedIndex].Ingredients[index];
    }

    public void Close()
    {
        SetProcess(false);
        Hide();
    }

    public void SetCenter(Vector2 center)
    {
        _requestedCenter = center;
        UpdateLayout();
        Position = Vector2.Zero;
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
        if (GetViewportRect().Size != _viewportSize)
        {
            UpdateLayout();
            QueueRedraw();
        }

        if (Input.IsActionJustPressed(PreviousPageAction))
        {
            ChangePage(-1);
        }
        else if (Input.IsActionJustPressed(NextPageAction))
        {
            ChangePage(1);
        }

        Vector2 controllerDirection = Input.GetVector(
            WheelLeftAction,
            WheelRightAction,
            WheelUpAction,
            WheelDownAction
        );
        if (!controllerDirection.IsZeroApprox())
        {
            _controllerSelectionActive = true;
            UpdateSelection(controllerDirection, 0.0f);
        }
        else if (!_controllerSelectionActive)
        {
            UpdateSelection(
                GetGlobalMousePosition() - _drawCenter,
                MouseDeadzoneSquared
            );
        }
    }

    public override void _Input(InputEvent inputEvent)
    {
        if (Visible && inputEvent is InputEventMouseMotion)
        {
            _controllerSelectionActive = false;
        }
    }

    private void UpdateSelection(
        Vector2 direction,
        float deadzoneSquared
    )
    {
        int displayedItemCount = GetDisplayedItemCount();
        if (
            displayedItemCount < 2
            || direction.LengthSquared() <= deadzoneSquared
        )
        {
            return;
        }

        float angle = Mathf.Atan2(direction.Y, direction.X) + Mathf.Pi * 0.5f;
        if (angle < 0.0f)
        {
            angle += Mathf.Tau;
        }

        int index = Mathf.PosMod(
            Mathf.FloorToInt(
                angle / Mathf.Tau * displayedItemCount + 0.5f
            ),
            displayedItemCount
        );
        index += _pageIndex * ItemsPerPage;
        if (_selectedIndex == index)
        {
            return;
        }

        _selectedIndex = index;
        QueueRedraw();
    }

    private void ChangePage(int offset)
    {
        if (PageCount < 2)
        {
            return;
        }

        int localIndex = _selectedIndex % ItemsPerPage;
        _pageIndex = Mathf.PosMod(_pageIndex + offset, PageCount);
        _selectedIndex = Mathf.Min(
            _pageIndex * ItemsPerPage + localIndex,
            _entries.Count - 1
        );
        UpdateLayout();
        QueueRedraw();
    }

    private int GetDisplayedItemCount()
    {
        return Mathf.Min(
            ItemsPerPage,
            _entries.Count - _pageIndex * ItemsPerPage
        );
    }

    private void UpdateLayout()
    {
        _viewportSize = GetViewportRect().Size;
        Size = _viewportSize;
        int displayedItemCount = GetDisplayedItemCount();
        if (displayedItemCount == 0)
        {
            return;
        }

        float shortestViewportSide = Mathf.Min(
            _viewportSize.X,
            _viewportSize.Y
        );
        float maxOuterRadius = Mathf.Max(
            MinimumItemRadius + WheelPadding,
            shortestViewportSide * 0.45f
        );
        float desiredOrbitRadius =
            displayedItemCount == 1
                ? 0.0f
                : Mathf.Max(
                    MinimumOrbitRadius,
                    displayedItemCount
                        * (DesiredItemRadius * 2.0f + ItemGap)
                        / Mathf.Tau
                );
        float maxOrbitRadius = Mathf.Max(
            0.0f,
            maxOuterRadius - DesiredItemRadius - WheelPadding
        );
        _orbitRadius = Mathf.Min(desiredOrbitRadius, maxOrbitRadius);

        float availableItemDiameter =
            displayedItemCount == 1
                ? DesiredItemRadius * 2.0f
                : Mathf.Tau * _orbitRadius
                    / displayedItemCount
                    - ItemGap;
        _itemRadius = Mathf.Clamp(
            availableItemDiameter * 0.5f,
            MinimumItemRadius,
            DesiredItemRadius
        );
        _backgroundRadius = _orbitRadius + _itemRadius + WheelPadding;
        _drawCenter = ClampCenterToViewport(
            _requestedCenter,
            _backgroundRadius
        );
    }

    private Vector2 ClampCenterToViewport(Vector2 center, float radius)
    {
        if (
            radius * 2.0f >= _viewportSize.X
            || radius * 2.0f >= _viewportSize.Y
        )
        {
            return _viewportSize * 0.5f;
        }

        return new Vector2(
            Mathf.Clamp(center.X, radius, _viewportSize.X - radius),
            Mathf.Clamp(center.Y, radius, _viewportSize.Y - radius)
        );
    }

    private int FindSelectedIndex(PickupItemDefinition? currentItem)
    {
        if (currentItem is not null)
        {
            for (int index = 0; index < _entries.Count; index++)
            {
                if (_entries[index].Ingredients[0].Id == currentItem.Id)
                {
                    return index;
                }
            }
        }

        return 0;
    }

    private int FindSelectedRecipeIndex(CookingRecipe? currentRecipe)
    {
        if (currentRecipe?.Output is not null)
        {
            for (int index = 0; index < _entries.Count; index++)
            {
                if (
                    _entries[index].Recipe?.Output?.Id
                    == currentRecipe.Output.Id
                )
                {
                    return index;
                }
            }
        }

        return 0;
    }

    public override void _Draw()
    {
        if (_entries.Count == 0)
        {
            return;
        }

        DrawCircle(
            _drawCenter,
            _backgroundRadius,
            new Color(0.04f, 0.08f, 0.14f, 0.94f)
        );
        DrawArc(
            _drawCenter,
            _backgroundRadius,
            0.0f,
            Mathf.Tau,
            64,
            BlueTint,
            3.0f
        );
        if (PageCount > 1)
        {
            float pageStep = Mathf.Tau / PageCount;
            DrawArc(
                _drawCenter,
                _backgroundRadius - 6.0f,
                -Mathf.Pi * 0.5f + _pageIndex * pageStep,
                -Mathf.Pi * 0.5f + (_pageIndex + 1) * pageStep,
                32,
                Colors.White,
                4.0f
            );
        }

        int displayedItemCount = GetDisplayedItemCount();
        int firstItemIndex = _pageIndex * ItemsPerPage;
        float step = Mathf.Tau / displayedItemCount;
        for (int localIndex = 0; localIndex < displayedItemCount; localIndex++)
        {
            int itemIndex = firstItemIndex + localIndex;
            float angle = -Mathf.Pi * 0.5f + localIndex * step;
            Vector2 itemCenter =
                _drawCenter + Vector2.FromAngle(angle) * _orbitRadius;
            bool selected = itemIndex == _selectedIndex;
            float radius =
                selected
                    ? Mathf.Min(
                        _itemRadius + 5.0f,
                        _itemRadius * 1.2f
                    )
                    : _itemRadius;
            DrawCircle(
                itemCenter,
                radius,
                selected
                    ? new Color(0.12f, 0.3f, 0.52f, 1.0f)
                    : new Color(0.1f, 0.14f, 0.2f, 1.0f)
            );
            DrawArc(
                itemCenter,
                radius,
                0.0f,
                Mathf.Tau,
                32,
                selected ? BlueTint : Colors.White,
                2.0f
            );
            DrawIngredientGroup(_entries[itemIndex].Ingredients, itemCenter);
        }
    }

    private void DrawIngredientGroup(
        List<PickupItemDefinition> ingredients,
        Vector2 center
    )
    {
        float spacing = _itemRadius * 0.85f;
        float startX = -spacing * (ingredients.Count - 1) * 0.5f;
        float maxIconSize =
            ingredients.Count == 1 ? _itemRadius * 1.5f : _itemRadius * 0.9f;
        for (int index = 0; index < ingredients.Count; index++)
        {
            PickupItemDefinition ingredient = ingredients[index];
            if (ingredient.Texture is null)
            {
                continue;
            }

            Vector2 size =
                ingredient.Texture.GetSize()
                * ingredient.VisualScale
                * 0.55f;
            float maxDimension = Mathf.Max(size.X, size.Y);
            if (maxDimension > maxIconSize)
            {
                size *= maxIconSize / maxDimension;
            }

            Vector2 iconCenter =
                center + Vector2.Right * (startX + index * spacing);
            DrawTextureRect(
                ingredient.Texture,
                new Rect2(iconCenter - size * 0.5f, size),
                false,
                ingredient.Modulate
            );
        }
    }
}