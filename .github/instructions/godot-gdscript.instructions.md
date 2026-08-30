---
name: "Godot GDScript"
description: "Use when writing or reviewing Godot GDScript gameplay code, Nodes, Resources, signals, input, physics, lifecycle methods, exports, or performance-sensitive loops."
applyTo: "**/*.gd"
---
# Godot GDScript Rules

- Target typed GDScript in Godot 4.7. Match an attachable `class_name` to the script's PascalCase type while keeping the filename `snake_case`.
- Preserve existing exported property names, types, defaults, ranges, groups, and units exactly. This project retains PascalCase export names so existing scenes and Resources continue to deserialize.
- Use `snake_case` for methods, signals, local variables, and non-exported properties. Update dynamic `call`, `get`, `set`, signal, and group method names with the same distinction.
- Keep engine callbacks thin. Put physics-affecting work in `_physics_process`; use `_process` for presentation and multiply continuous frame motion by `delta`.
- Resolve required node references once in `_ready`, inject them from the owning scene, or export typed node references. Avoid repeated path lookups in hot callbacks.
- Prefer typed signal-object connections. Disconnect in the matching lifecycle when an emitter can outlive the receiver.
- Use `StringName` values for stable input actions, groups, and repeated dynamic identifiers.
- Avoid per-frame allocations, unbounded searches, repeated native property access, and unnecessary string conversions in measured hot paths.
- Surface invalid required state with `push_error` and an explicit failure return consistent with the surrounding contract; do not silently succeed.
- Keep Web compatibility: do not introduce .NET/native dependencies or thread requirements without proving a supported browser path and updating export validation.

Before relying on an unfamiliar API, query the connected editor's ClassDB. After GDScript changes, check parser/import diagnostics, then run the narrowest editor and runtime validation that observes the behavior.
