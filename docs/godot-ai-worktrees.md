# Godot AI with parallel Windows worktrees

This repository uses Godot AI plugin 3.1.5 and its standard shared backend:

- MCP clients connect through the generated `godot-ai attach` configuration.
- Editors connect to the same backend and appear as separate sessions.
- Worktrees do not receive separate MCP ports.
- `session_manage` with `op: "list"` is the public MCP operation that invokes Godot AI's internal `session_list` handler.

## One-time MCP client setup

Open any editor with the plugin enabled. In the **Godot AI** dock, select the MCP client and choose **Configure**. The generated configuration launches the version-matched `godot-ai attach` bridge for the normal shared server. Do not add per-worktree ports or hand-write a different server command.

## Start and resolve a worktree

From the worktree root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\godot-ai\Start-GodotWorktree.ps1 -GodotPath 'C:\path\to\Godot.exe'
$sessionId = powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\godot-ai\Get-GodotAISession.ps1 -GodotPath 'C:\path\to\Godot.exe'
```

Instead of passing `-GodotPath` each time, set `GODOT_EXE` to the executable. `GODOT_PATH` and `godot`/`godot4` on `PATH` are also supported. For C# projects, the launcher selects an installed .NET SDK that matches the Godot executable architecture and passes that environment to Godot; runtime-only and mismatched-architecture installations are rejected. The bootstrap starts this worktree's editor if needed, lists Godot AI sessions, matches the canonical project path, performs an explicitly routed `editor_state` read, and prints only the exact session ID.

Session discovery and revalidation lists are global because no target ID is known or trusted until the result is matched. For every targetable Godot AI call, pass the retained ID as the top-level `session_id` argument. Do not use `session_activate`; activation is shared global state. Re-run the bootstrap after an editor restart or reconnect.

Before an editor mutation, revalidate the retained ID:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\godot-ai\Get-GodotAISession.ps1 -ExpectedSessionId $sessionId
```

The command fails if the canonical path has zero or multiple sessions, or if its sole session no longer has the expected ID.

## Run several worktrees

Run the two commands above in each worktree. Each command finds `project.godot` relative to its own checkout, while every editor uses the normal shared backend. Never select the first returned session: worktree routing is valid only when exactly one returned `project_path` canonically matches the current checkout.

Stop only the current worktree's editor:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\godot-ai\Start-GodotWorktree.ps1 -Action Stop
```

The stop action targets a process only after its `--path` resolves to this worktree. It requests a graceful window close so Godot can show save prompts, refuses ambiguous duplicate editors, and never force-terminates on timeout. Runtime diagnostics are written under the user's local application data directory, not the repository.

## Troubleshooting

| Symptom | Action |
|---|---|
| Duplicate matching sessions | Close duplicate editors for this exact worktree, wait for disconnect, then resolve again. The script fails instead of choosing one. |
| Stale session | Confirm the old editor process is gone, reconnect or restart only this worktree's editor, then resolve again. Do not activate or close another worktree's session. |
| Path mismatch | Compare `session_manage(op: "list")` results with the canonical worktree path. Junctions, stale checkouts, and differently spelled paths must resolve to the same existing directory. If they do not, stop. |
| No MCP server | Verify `uv` is installed and use the Godot AI dock's generated client configuration. Keep the default shared-server architecture. |
| `BadImageFormatException` loading `Microsoft.Build.dll` | Install a .NET SDK with the same architecture as the Godot executable, then start the editor through the worktree launcher. |
| Plugin unavailable | Confirm `addons/godot_ai/plugin.cfg` exists and `project.godot` enables `res://addons/godot_ai/plugin.cfg`. |
| Non-default shared endpoint | Set `GODOT_AI_MCP_URL` or pass `-McpUrl`. Use one shared endpoint; do not allocate a port per worktree. |
