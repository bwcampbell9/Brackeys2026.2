# Agent Engineering Contract

## Work From Evidence

- Inspect the owning scene, script, resource, and nearest test before changing behavior.
- State the behavior to preserve or add as an observable acceptance criterion.
- Form one falsifiable hypothesis and choose the cheapest check that could disprove it.
- Prefer Godot ClassDB and the connected Godot AI MCP over recalled API signatures.
- Label assumptions and report checks that could not run. Never present an unexecuted check as passing.

## Godot AI Worktree Routing

- At the beginning of editor-, scene-, or runtime-dependent work, run `scripts/godot-ai/Get-GodotAISession.ps1` and retain the exact session ID resolved for this worktree's canonical project path.
- Except for the initial discovery list that obtains the ID, pass that exact ID as the top-level `session_id` argument on every Godot AI MCP tool call that supports it. Never rely on the globally active session, select the first listed session, or use `session_activate` as a routing substitute.
- Re-resolve the session after Godot restarts or reconnects.
- Immediately before any mutation, run `Get-GodotAISession.ps1 -ExpectedSessionId <retained-id>`. It must globally list sessions and verify that exactly one canonical-path match still has the retained ID.
- If the path or routing cannot be verified, stop. Do not operate on a guessed session.
- Do not close, restart, activate, or modify another worktree's Godot session.
- Filesystem-only inspection does not require launching Godot. Engine-connected scene/editor/ClassDB/import/runtime operations do.
- See `docs/godot-ai-worktrees.md` for setup and troubleshooting.

## Parallel Worktree Collaboration

- Before editing in parallel, the coordinating parent session must maintain the active reservation table and acknowledge the base commit, acceptance criteria, owned paths, shared contracts, dependencies, and integration order. Pass the complete active reservation set in every child kickoff. A child must wait for coordinator approval before expanding its paths.
- Use one active writer per file. Assign cohesive vertical slices--a scene or component with its scripts, resources, and tests--rather than splitting tightly coupled files between agents.
- Treat `project.godot`, autoloads, input actions, plugin lists, main-scene composition, solution/build files, export settings, `.gitattributes`, and `.gitignore` as integration-owner files. Other worktrees must request an exact delta or wait.
- Prefer separate child scenes and external resources for independently owned content. Keep their public signals, exports, groups, resource paths, and action names stable; let one integration owner compose them into a shared parent scene.
- Never save unrelated open scenes or resources. Before handoff, inspect the diff for editor churn, rewritten IDs, ownership changes, duplicated embedded resources, and files outside the declared ownership.
- Never edit or commit `.godot/` or imported cache artifacts. Keep generated script/shader `.uid` identity sidecars and imported-asset `.import` metadata with their owning source. Never hand-edit a UID, replace an existing UID casually, or move/delete a sidecar independently; let Godot generate a genuinely missing sidecar and review it with the source change.
- Treat binary assets as single-writer files. Use Git LFS only when repository policy already enables it; LFS storage does not make binary files mergeable.
- Keep a private branch per worktree. Do not switch, reset, delete, force-update, or rebase a branch used by another worktree. Rebase only an unpublished private branch; otherwise merge the integration tip.
- A clean textual merge is not proof of compatibility. Integrate one dependency-ordered branch at a time and validate the resulting integrated commit.
- Handoffs require a focused commit and clean worktree. They must name the base and resulting commits, actual touched paths including untracked files, changed shared contracts, dependency order, checks and outcomes, and remaining risks. See `docs/worktree-collaboration.md`.

## Design For Games

- Use C# for all game and project code wherever Godot supports the required feature. Use GDScript only when the feature is unavailable in C#; keep that boundary minimal and document the reason.
- Keep the smallest direct design that supports the behavior proven necessary today.
- Separate deterministic game rules and state transitions from engine callbacks, input sampling, rendering, audio, and persistence where practical.
- Put physics-affecting work in fixed physics ticks. Keep presentation work in render-time processing.
- Prefer composition and explicit dependencies. Add interfaces, managers, events, or global state only when they solve demonstrated coupling or variation.
- Treat scenes as cohesive reusable units, Resources as serializable designer-authored data, and Nodes as lifecycle or engine integration points.
- Make randomness, time, and external input controllable when repeatability matters.
- Optimize from measurements. Record the baseline, target, test conditions, and result.

## Change Loop

1. Establish an observable baseline or failing check.
2. Make one behavior-sized change.
3. Run the narrowest relevant build or automated test immediately.
4. Run the affected scene and inspect logs, runtime state, and visuals when behavior is engine-dependent.
5. Review the diff for accidental scene/resource churn and unrelated edits.

Use the `game-feature-loop`, `godot-validation`, and `game-engineering-research` skills for detailed procedures.

## Boundaries

- Preserve user changes in the working tree.
- Do not edit generated `.godot/`, imported artifacts, or third-party `addons/` code unless the task explicitly targets them.
- Use Godot editor or MCP operations for scene and resource mutations when available; they preserve engine semantics better than ad hoc text edits.
- Keep commits and changes focused. Do not refactor unrelated code while delivering a feature or fix.