using System;
using System.Collections.Generic;
using Godot;

public partial class TaskBroker : Node
{
    private readonly record struct TaskKey(
        ulong PublisherId,
        int Generation,
        NpcTaskKind Kind
    );

    private readonly Dictionary<long, NpcTaskRequest> _tasks = new();
    private readonly Dictionary<TaskKey, long> _taskIdsByKey = new();
    private long _nextTaskId = 1;

    [Signal]
    public delegate void TasksChangedEventHandler();

    public int OpenTaskCount => CountTasks(NpcTaskStatus.Open);

    public int ClaimedTaskCount => CountTasks(NpcTaskStatus.Claimed);

    public long Publish(
        NpcTaskDefinition definition,
        WorkstationTaskPublisher destination,
        int generation,
        PickupItemDefinition? requestedItem,
        PickupItemDefinition? requiredTool
    )
    {
        ArgumentNullException.ThrowIfNull(definition);
        ArgumentNullException.ThrowIfNull(destination);

        TaskKey key = new(
            destination.GetInstanceId(),
            generation,
            definition.Kind
        );
        if (
            _taskIdsByKey.TryGetValue(key, out long existingId)
            && _tasks.TryGetValue(existingId, out NpcTaskRequest? existing)
            && existing.Status is NpcTaskStatus.Open or NpcTaskStatus.Claimed
        )
        {
            return existingId;
        }

        long taskId = _nextTaskId++;
        _tasks.Add(
            taskId,
            new NpcTaskRequest
            {
                Id = taskId,
                Generation = generation,
                Definition = definition,
                Destination = destination,
                RequestedItem = requestedItem,
                RequiredTool = requiredTool,
            }
        );
        _taskIdsByKey[key] = taskId;
        EmitSignal(SignalName.TasksChanged);
        return taskId;
    }

    public bool TryClaim(
        Node claimant,
        IReadOnlySet<StringName> capabilityTags,
        Vector2 origin,
        Predicate<NpcTaskRequest> isReady,
        out NpcTaskRequest? task
    )
    {
        ArgumentNullException.ThrowIfNull(claimant);
        ArgumentNullException.ThrowIfNull(capabilityTags);
        ArgumentNullException.ThrowIfNull(isReady);

        task = null;
        foreach (NpcTaskRequest candidate in _tasks.Values)
        {
            if (
                candidate.Status != NpcTaskStatus.Open
                || !IsEligible(candidate.Definition, capabilityTags)
                || !isReady(candidate)
                || (
                    task is not null
                    && !IsHigherPriority(candidate, task, origin)
                )
            )
            {
                continue;
            }

            task = candidate;
        }

        if (task is null)
        {
            return false;
        }

        task.Status = NpcTaskStatus.Claimed;
        task.Claimant = claimant;
        EmitSignal(SignalName.TasksChanged);
        return true;
    }

    public bool Release(long taskId, Node claimant)
    {
        if (
            !_tasks.TryGetValue(taskId, out NpcTaskRequest? task)
            || task.Status != NpcTaskStatus.Claimed
            || task.Claimant != claimant
        )
        {
            return false;
        }

        task.Status = NpcTaskStatus.Open;
        task.Claimant = null;
        EmitSignal(SignalName.TasksChanged);
        return true;
    }

    public bool Complete(long taskId, Node claimant)
    {
        if (
            !_tasks.TryGetValue(taskId, out NpcTaskRequest? task)
            || task.Status != NpcTaskStatus.Claimed
            || task.Claimant != claimant
        )
        {
            return false;
        }

        task.Status = NpcTaskStatus.Completed;
        task.Claimant = null;
        EmitSignal(SignalName.TasksChanged);
        return true;
    }

    public bool Cancel(long taskId)
    {
        if (
            !_tasks.TryGetValue(taskId, out NpcTaskRequest? task)
            || task.Status is NpcTaskStatus.Completed or NpcTaskStatus.Canceled
        )
        {
            return false;
        }

        task.Status = NpcTaskStatus.Canceled;
        task.Claimant = null;
        EmitSignal(SignalName.TasksChanged);
        return true;
    }

    public NpcTaskStatus? GetStatus(long taskId)
    {
        return _tasks.TryGetValue(taskId, out NpcTaskRequest? task)
            ? task.Status
            : null;
    }

    private int CountTasks(NpcTaskStatus status)
    {
        int count = 0;
        foreach (NpcTaskRequest task in _tasks.Values)
        {
            if (task.Status == status)
            {
                count++;
            }
        }

        return count;
    }

    private static bool IsEligible(
        NpcTaskDefinition definition,
        IReadOnlySet<StringName> capabilityTags
    )
    {
        foreach (StringName requiredTag in definition.RequiredTags)
        {
            if (!capabilityTags.Contains(requiredTag))
            {
                return false;
            }
        }

        return true;
    }

    private static bool IsHigherPriority(
        NpcTaskRequest candidate,
        NpcTaskRequest current,
        Vector2 origin
    )
    {
        if (candidate.Definition.Priority != current.Definition.Priority)
        {
            return candidate.Definition.Priority > current.Definition.Priority;
        }

        float candidateDistance = origin.DistanceSquaredTo(
            candidate.Destination.ApproachPosition
        );
        float currentDistance = origin.DistanceSquaredTo(
            current.Destination.ApproachPosition
        );
        return !Mathf.IsEqualApprox(candidateDistance, currentDistance)
            ? candidateDistance < currentDistance
            : candidate.Id < current.Id;
    }
}
