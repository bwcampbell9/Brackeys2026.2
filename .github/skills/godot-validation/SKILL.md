---
name: godot-validation
description: "Validate Godot, GDScript, and C# changes with a risk-based evidence ladder using diagnostics, language-specific builds when applicable, Godot AI editor tests, scene inspection, runtime input, node state, logs, screenshots, and performance monitors. Use after edits, for regressions, reviews, test design, and completion checks."
argument-hint: "Changed behavior or files to validate"
---
# Godot Validation

Read [test-strategy.md](./test-strategy.md) when choosing or adding tests.

## Evidence Ladder

Stop at the lowest level that can falsify the claim, but climb high enough to observe engine-dependent behavior.

1. **Static:** GDScript parser/editor diagnostics; `dotnet build` only when C# is actually present and the SDK is available.
2. **Logic:** fast deterministic tests for rules, state transitions, calculations, serialization, and seeded randomness.
3. **Editor/scene:** Godot AI filtered tests, hierarchy inspection, required properties, resources, groups, signals, collision layers, and input actions.
4. **Runtime:** launch the affected scene, inject actions, inspect runtime nodes/properties, and read fresh errors.
5. **Presentation:** capture at least one representative frame and inspect text, composition, animation state, visibility, and relevant viewport sizes.
6. **Performance:** compare the same scenario, build mode, hardware, duration, and metric against a recorded baseline.
7. **Experience:** human playtest for feel, readability, comfort, balance, accessibility, and fun.

Compilation alone does not prove a scene works. A screenshot alone does not prove interaction. Automated checks do not prove game feel.

## Godot AI Runtime Loop

1. Inspect editor state and confirm the intended scene/version/session.
2. Clear or timestamp logs so old failures cannot contaminate the result.
3. Run a narrow editor test with suite/test filters when one exists.
4. Launch the main, current, or explicit scene. Confirm the game helper is live.
5. Inspect the runtime scene tree and target node before input.
6. Send action-based input. Use one frame-timed input sequence for jumps, combos, triggers, and other timing-sensitive behavior.
7. Inspect resulting node properties, UI elements, or a small `game_eval` query.
8. Capture the running game when visuals changed and inspect the actual pixels.
9. Read fresh errors and relevant performance monitors.
10. Stop the game when the check is complete.

Use action input rather than raw keys unless testing physical key mapping. Release every pressed action. Never infer success only because launch returned without error.

## Failure Handling

- Reproduce before changing code and preserve the failing evidence.
- If a result is ambiguous, add one discriminating assertion or runtime observation, not a broad rewrite.
- Treat skipped tests, stale logs, the wrong edited scene, zero assertions, or an unavailable helper as incomplete evidence.
- If .NET SDK, Godot CLI, target hardware, credentials, or a human evaluator is unavailable, report that boundary and run the remaining levels.
- Do not install a test framework during validation unless the task explicitly includes test infrastructure.

## Integrated Worktree Validation

After combining worktree branches, validate the integrated commit rather than carrying forward branch-local results:

1. inspect changed paths, conflict markers, `.godot/` leakage, unrelated editor churn, and appropriate script/shader `.uid` or imported-asset `.import` pairing;
2. inspect every resolved `.tscn`, `.tres`, `project.godot`, and `.import` conflict for resource IDs, node ownership, external references, autoloads, plugins, input actions, and import settings; verify conflicted `.uid` files preserve one intended source identity;
3. compile and run the focused tests for all integrated slices;
4. resolve the integration worktree's exact Godot AI session, poll the explicitly routed `editor_state` until readiness is not `importing` with a bounded timeout, and load every changed scene/resource plus the shared parent or main scene;
5. exercise cross-slice contracts and read fresh parser, import, editor, and runtime errors;
6. inspect the Git diff again after import or scene load so generated or unrelated saves do not enter the handoff.

A conflict-free merge can still contain incompatible signals, exports, paths, action names, resource assumptions, or lifecycle behavior.

## Completion Record

```text
Claim:
Static:
Automated:
Runtime:
Visual/performance:
Not verified:
```
