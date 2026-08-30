using Godot;
using System.Threading.Tasks;

public partial class CircleTransition : CanvasLayer
{
    private static readonly StringName CenterUvParameter = "center_uv";
    private static readonly StringName RadiusProgressParameter = "radius_progress";
    private const string ShaderPath = "res://assets/shaders/circle_transition.gdshader";

    private ShaderMaterial _material = null!;

    public override void _Ready()
    {
        Layer = 100;
        ProcessMode = ProcessModeEnum.Always;

        _material = new ShaderMaterial
        {
            Shader = GD.Load<Shader>(ShaderPath),
        };

        ColorRect overlay = new()
        {
            Color = Colors.Black,
            Material = _material,
            MouseFilter = Control.MouseFilterEnum.Stop,
        };
        overlay.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        AddChild(overlay);
    }

    public async Task<Error> TransitionToScene(
        string scenePath,
        NodePath revealTargetPath,
        Vector2 closeCenter,
        bool revealAtViewportCenter = false,
        bool unpauseBeforeSceneChange = false,
        float closeDuration = 0.35f,
        float openDuration = 0.8f
    )
    {
        await AnimateRadius(closeCenter, 1.0f, 0.0f, closeDuration);

        SceneTree tree = GetTree();
        if (unpauseBeforeSceneChange)
        {
            tree.Paused = false;
        }

        Error result = tree.ChangeSceneToFile(scenePath);
        if (result != Error.Ok)
        {
            GD.PushError($"Could not change to scene '{scenePath}': {result}.");
            QueueFree();
            return result;
        }

        for (int frame = 0; frame < 3 && tree.CurrentScene is null; frame++)
        {
            await ToSignal(tree, SceneTree.SignalName.ProcessFrame);
        }

        Vector2 revealCenter;
        if (revealAtViewportCenter)
        {
            revealCenter = GetViewport().GetVisibleRect().Size * 0.5f;
        }
        else
        {
            Node2D? revealTarget = tree.CurrentScene?.GetNodeOrNull<Node2D>(revealTargetPath);
            if (revealTarget is null)
            {
                GD.PushError(
                    $"Circle transition could not find reveal target '{revealTargetPath}' in '{scenePath}'."
                );
                QueueFree();
                return Error.DoesNotExist;
            }

            revealCenter = revealTarget.GetGlobalTransformWithCanvas().Origin;
        }

        await AnimateRadius(revealCenter, 0.0f, 1.0f, openDuration);
        QueueFree();
        return Error.Ok;
    }

    private async Task AnimateRadius(
        Vector2 center,
        float startRadius,
        float endRadius,
        float duration
    )
    {
        Vector2 viewportSize = GetViewport().GetVisibleRect().Size;
        _material.SetShaderParameter(CenterUvParameter, center / viewportSize);
        _material.SetShaderParameter(RadiusProgressParameter, startRadius);

        Tween tween = CreateTween()
            .SetPauseMode(Tween.TweenPauseMode.Process)
            .SetTrans(Tween.TransitionType.Cubic)
            .SetEase(
                endRadius > startRadius
                    ? Tween.EaseType.Out
                    : Tween.EaseType.In
            );
        tween.TweenMethod(
            Callable.From<float>(SetRadiusProgress),
            startRadius,
            endRadius,
            Mathf.Max(duration, 0.05f)
        );
        await ToSignal(tween, Tween.SignalName.Finished);
    }

    private void SetRadiusProgress(float progress)
    {
        _material.SetShaderParameter(RadiusProgressParameter, progress);
    }
}
