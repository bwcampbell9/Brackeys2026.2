using System;
using Godot;

public partial class WorkerConfiguration : CharacterBody2D
{
    [ExportGroup("Worker Difficulty")]
    [Export(PropertyHint.Range, "0,1,0.01")]
    public float ErrorRate { get; set; } = 0.6f;

    [ExportGroup("Dependencies")]
    [Export]
    public NodePath TaskRunnerPath { get; set; } = new("NpcTaskRunner");

    public override void _Ready()
    {
        if (ErrorRate is < 0.0f or > 1.0f)
        {
            throw new InvalidOperationException(
                $"{Name} requires a worker error rate between 0 and 1."
            );
        }

        NpcTaskRunner runner =
            GetNodeOrNull<NpcTaskRunner>(TaskRunnerPath)
            ?? throw new InvalidOperationException(
                $"{Name} requires an NpcTaskRunner."
            );
        NpcPersonality sourcePersonality =
            runner.Personality
            ?? throw new InvalidOperationException(
                $"{Name} requires an NpcPersonality."
            );

        var instancePersonality = (NpcPersonality)sourcePersonality.Duplicate(
            true
        );
        instancePersonality.FailureChance = ErrorRate;
        runner.Personality = instancePersonality;
    }
}
