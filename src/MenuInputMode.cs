using Godot;

public static class MenuInputMode
{
    public static bool IsControllerActive { get; private set; }

    public static void DeactivateController()
    {
        IsControllerActive = false;
    }

    public static bool Observe(InputEvent @event)
    {
        if (
            @event is InputEventJoypadButton { Pressed: true }
            || @event is InputEventJoypadMotion joypadMotion
                && Mathf.Abs(joypadMotion.AxisValue) >= 0.5f
        )
        {
            IsControllerActive = true;
            return true;
        }

        if (
            @event is InputEventMouseMotion
            || @event is InputEventMouseButton
            || @event is InputEventKey { Pressed: true, Echo: false }
        )
        {
            IsControllerActive = false;
            return true;
        }

        return false;
    }

    public static bool IsMouseDrag(InputEvent @event)
    {
        return @event is InputEventMouseMotion mouseMotion
            && mouseMotion.ButtonMask != (MouseButtonMask)0;
    }

    public static bool IsMouseRelease(InputEvent @event)
    {
        return @event is InputEventMouseButton { Pressed: false };
    }
}
