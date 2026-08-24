# Parallel worktree collaboration

Parallel worktrees isolate files and editor processes; they do not make overlapping changes independent. Use one writer per file, explicit dependency order, and validation on the integrated commit.

## Plan ownership

The parent coordination session owns the active reservation table. Before creating a child worktree, it records:

```text
Base commit:
Worktree/branch:
Acceptance criteria:
Owned paths:
Shared contracts:
Dependencies:
Integration order:
```

Pass the complete active reservation table in every child kickoff and require the child to acknowledge its reservation before editing. A child that discovers another required path messages the coordinator and waits; only the coordinator updates reservations. Keep this coordination state in the parent session and session messages, not a tracked repository file that would itself conflict. If work is coordinated outside the Copilot app, use one shared issue/PR record with the same single-writer update rule.

Assign a cohesive vertical slice to each worktree: a child scene or component, its scripts and resources, its tests, and any exclusively owned assets. Different files can still conflict semantically, so list signals, exports, groups, input actions, autoloads, resource paths, and public C# APIs that another slice consumes.

Use one integration owner for hotspots:

- `project.godot`, autoloads, input actions, plugins, and main scene;
- shared parent scenes and shared `.tres` resources;
- project/solution, build, export, ignore, and attributes files;
- third-party addons and dependency manifests.

If a slice needs a hotspot change, give the integration owner an exact requested delta or sequence that change before dependent work. Do not let two worktrees save the same scene and hope to merge it later.

## Structure Godot work for parallelism

Prefer cohesive, self-contained child scenes and external resources for content that changes independently. Let one owner instance those children in a shared parent. Communicate through stable exports, signals, groups, and injected references instead of hard-coded sibling paths or new global state.

This is a conflict-reduction heuristic, not a reason to fragment a small scene prematurely. Sequence a small shared edit when extraction would add more coupling than it removes.

| Path type | Parallel rule |
|---|---|
| Independent `.cs`, `.tscn`, `.tres`, and tests | Separate writers are usually safe when public contracts do not drift |
| Same scene, resource, script, or binary asset | One writer |
| `project.godot` and other hotspots above | Integration owner only |
| `.godot/**` and imported cache | Never edit, copy between worktrees, or commit |
| Script/shader `.uid` | Preserve source identity; never hand-edit or casually replace an existing UID |
| Imported-asset `.import` | Keep import metadata/settings with the owning source asset |
| Binary art/audio/model files | One writer; Git LFS storage does not make them mergeable |

## Handoff and integration

Keep worktree branches private, focused, runnable, and short-lived. Do not switch, reset, delete, force-update, or rebase a branch another worktree uses. Rebase only unpublished private work; otherwise merge the current integration tip.

Before handoff, run `git status --short` and `git diff --check`; compare tracked and untracked paths with the approved reservation. Create a focused commit, record `HEAD`, and require a clean worktree. Every handoff includes:

```text
Base and result commits:
Actual touched paths:
Shared contracts changed:
Dependencies/integration order:
Checks and outcomes:
Unverified risks:
```

The integration owner:

1. compares actual paths with declared ownership;
2. integrates foundational contracts/assets before dependents;
3. integrates one branch at a time;
4. treats conflicts in `project.godot`, `.tscn`, `.tres`, and `.import` as structured-data conflicts--never blind `ours`/`theirs`--and resolves `.uid` conflicts by preserving the intended source identity rather than combining tokens;
5. validates after each integration so the branch that introduced a regression remains identifiable.

If an integration fails, stop before merging another branch. Preserve any pre-existing dirty state and use `git merge --abort` only for the merge started by the integration owner. Do not use `git reset --hard`, `git clean`, checkout-based file restoration, force pushes, or worktree removal to recover without explicit authorization. Diagnose and repair in the owning branch, or revert the focused integration commit when reverting is the agreed recovery.

## Validate the combined result

On the integration worktree:

1. reject conflict markers, `.godot/` leakage, unrelated saves, and inappropriate source/`.uid`/`.import` changes;
2. inspect scene ownership, resource IDs/references, exports, signals, groups, autoloads, plugins, and input actions;
3. compile and run focused tests for every integrated slice;
4. resolve that worktree's exact Godot AI `session_id`;
5. poll explicitly routed `editor_state` until readiness is not `importing`, with a bounded timeout, then load changed scenes/resources and their shared parent or main scene;
6. run cross-slice acceptance scenarios and inspect fresh import, parser, editor, and runtime logs;
7. inspect the Git diff again after the editor check.

A clean merge proves only that Git combined text. It does not prove that scene references, APIs, gameplay behavior, or assets remain compatible.

## Source basis

The mandatory rules are based on Git's documented worktree/merge behavior and Godot's version-control, import, UID, resource, and scene-format behavior. File-level ownership, small changes, child-scene partitioning, and serialized integration are engineering heuristics chosen to reduce textual and higher-order conflicts. Source links are maintained in `.github/skills/game-engineering-research/sources.md`.
