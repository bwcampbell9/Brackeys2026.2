using System;
using System.Collections.Generic;
using Godot;

public partial class ItemSourceCatalog : Node
{
    public static readonly StringName ItemSourceGroup = "npc_item_sources";

    private readonly Dictionary<ulong, Node> _reservations = new();
    private Node? _scopeRoot;

    public void Configure(Node scopeRoot)
    {
        ArgumentNullException.ThrowIfNull(scopeRoot);
        _scopeRoot = scopeRoot;
        _reservations.Clear();
    }

    public List<PickupItemDefinition> GetAvailableDefinitionsExcluding(
        PickupItemDefinition excluded,
        Node requester
    )
    {
        List<PickupItemDefinition> definitions = new();
        HashSet<StringName> seenIds = new();
        foreach (IItemSource source in GetAvailableSources(requester))
        {
            PickupItemDefinition? definition = source.AvailableDefinition;
            if (
                definition is null
                || HasSameId(definition, excluded)
                || !seenIds.Add(definition.Id)
            )
            {
                continue;
            }

            definitions.Add(definition);
        }

        definitions.Sort(
            static (left, right) =>
                string.CompareOrdinal(left.Id.ToString(), right.Id.ToString())
        );
        return definitions;
    }

    public bool HasAvailableSource(
        PickupItemDefinition definition,
        Node requester
    )
    {
        ArgumentNullException.ThrowIfNull(definition);
        ArgumentNullException.ThrowIfNull(requester);

        foreach (IItemSource source in GetAvailableSources(requester))
        {
            if (
                source.AvailableDefinition is PickupItemDefinition available
                && HasSameId(available, definition)
            )
            {
                return true;
            }
        }

        return false;
    }

    public IItemSource? FindReturnSource(
        PickupItemDefinition definition
    )
    {
        ArgumentNullException.ThrowIfNull(definition);

        IItemSource? result = null;
        foreach (Node node in GetTree().GetNodesInGroup(ItemSourceGroup))
        {
            if (
                !IsWithinScope(node)
                || node is not IItemSource source
                || !source.CanReturnItem
                || source.AvailableDefinition
                    is not PickupItemDefinition available
                || !HasSameId(available, definition)
            )
            {
                continue;
            }

            if (
                result is null
                || source.SourceNode.GetInstanceId()
                    < result.SourceNode.GetInstanceId()
            )
            {
                result = source;
            }
        }

        return result;
    }

    public bool TryReserveSource(
        PickupItemDefinition definition,
        Node requester,
        RandomNumberGenerator random,
        out IItemSource? source
    )
    {
        ArgumentNullException.ThrowIfNull(definition);
        ArgumentNullException.ThrowIfNull(requester);
        ArgumentNullException.ThrowIfNull(random);

        List<IItemSource> candidates = new();
        foreach (IItemSource candidate in GetAvailableSources(requester))
        {
            if (
                candidate.AvailableDefinition
                    is PickupItemDefinition available
                && HasSameId(available, definition)
            )
            {
                candidates.Add(candidate);
            }
        }

        if (candidates.Count == 0)
        {
            source = null;
            return false;
        }

        source = candidates[random.RandiRange(0, candidates.Count - 1)];
        _reservations[source.SourceNode.GetInstanceId()] = requester;
        return true;
    }

    public void Release(IItemSource? source, Node requester)
    {
        if (source is null)
        {
            return;
        }

        ulong sourceId = source.SourceNode.GetInstanceId();
        if (
            _reservations.TryGetValue(sourceId, out Node? owner)
            && owner == requester
        )
        {
            _reservations.Remove(sourceId);
        }
    }

    private List<IItemSource> GetAvailableSources(Node requester)
    {
        PruneReservations();
        List<IItemSource> sources = new();
        foreach (Node node in GetTree().GetNodesInGroup(ItemSourceGroup))
        {
            if (
                !IsWithinScope(node)
                || node is not IItemSource source
                || !source.IsSourceAvailable
                || (
                    _reservations.TryGetValue(
                        source.SourceNode.GetInstanceId(),
                        out Node? owner
                    )
                    && owner != requester
                )
            )
            {
                continue;
            }

            sources.Add(source);
        }

        sources.Sort(
            static (left, right) =>
                left.SourceNode.GetInstanceId().CompareTo(
                    right.SourceNode.GetInstanceId()
                )
        );
        return sources;
    }

    private bool IsWithinScope(Node node)
    {
        return _scopeRoot is not null
            && (
                node == _scopeRoot
                || _scopeRoot.IsAncestorOf(node)
            );
    }

    private static bool HasSameId(
        PickupItemDefinition left,
        PickupItemDefinition right
    )
    {
        return !left.Id.IsEmpty && left.Id == right.Id;
    }

    private void PruneReservations()
    {
        List<ulong>? staleIds = null;
        foreach (KeyValuePair<ulong, Node> reservation in _reservations)
        {
            if (GodotObject.IsInstanceValid(reservation.Value))
            {
                continue;
            }

            staleIds ??= new List<ulong>();
            staleIds.Add(reservation.Key);
        }

        if (staleIds is null)
        {
            return;
        }

        foreach (ulong staleId in staleIds)
        {
            _reservations.Remove(staleId);
        }
    }
}
