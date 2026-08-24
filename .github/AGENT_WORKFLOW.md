# Agentic Game Development

The default agent contract is loaded from `copilot-instructions.md`. Detailed workflows load only when relevant.

## Use

| Need | Skill, prompt, or agent |
|---|---|
| Implement or fix gameplay | `/game-feature-loop` |
| Validate a change | `/godot-validation` |
| Research an unfamiliar decision | `/game-engineering-research` |
| Isolate research from implementation context | `/research-game-engineering` or **Game Engineering Researcher** |
| Independent read-only review | `/review-game-change` or **Gameplay Reviewer** |

Normal requests can trigger these automatically. Slash commands are useful when you want the workflow explicitly.

## Expected Loop

1. Define observable acceptance criteria.
2. Inspect the owning code and scene.
3. State a falsifiable hypothesis and first check.
4. Make one behavior-sized edit.
5. Run static and focused automated checks.
6. Exercise the affected scene through Godot AI; inspect state, logs, and pixels.
7. Review risks and report anything not verified.

## Parallel Worktrees

1. Before delegation, the parent coordinator records an active reservation table, compares planned paths/contracts, and sends the complete table in each child kickoff. Reserve every file to one writer and designate one integration owner for global settings and shared parent scenes.
2. Partition by cohesive vertical slice. Prefer separate child scenes/resources with their scripts and tests; do not assign one agent the scene and another its tightly coupled script.
3. Integrate foundational contracts and assets before their dependents. Keep branches short-lived and hand off small runnable commits.
4. Before handoff, run `git status --short` and `git diff --check`, compare tracked and untracked paths with declared ownership, remove accidental editor churn, create a focused commit, and confirm the worktree is clean. Never transfer generated `.godot/` state between worktrees.
5. Bring each private branch to the current integration tip without rewriting another worktree's history, then integrate one branch at a time in dependency order.
6. Resolve conflicts in `project.godot`, `.tscn`, `.tres`, and `.import` as structured Godot data. For `.uid`, preserve the intended source identity rather than combining tokens. Never accept `ours` or `theirs` blindly.
7. Re-run focused and engine-connected validation on each integrated commit. Branch-local success does not prove the combined result.

Use `../docs/worktree-collaboration.md` for ownership, handoff, integration, and recovery details.

## Prerequisites

- Godot .NET matching the project SDK, with the Godot AI plugin enabled and connected.
- A compatible x64 .NET SDK (`dotnet --info` should list the required target framework).
- VS Code C# tooling for diagnostics and debugging.

Use **Tasks: Run Build Task** for the standard `dotnet build`. Engine-connected validation should use Godot AI because the Godot executable does not need to be on `PATH`.

For parallel worktrees, follow the mandatory session-routing rules in `copilot-instructions.md` and the setup in `../docs/godot-ai-worktrees.md`. Resolve by canonical project path and route every supported MCP call with the exact `session_id`.

No global lifecycle hook runs builds after every tool call. Validation is behavior-scoped so scene launches and test runs happen when they can provide relevant evidence.
