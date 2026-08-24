---
name: "Godot C#"
description: "Use when writing or reviewing Godot C# gameplay code, Nodes, Resources, signals, input, physics, lifecycle methods, exports, or performance-sensitive loops."
applyTo: "**/*.cs"
---
# Godot C# Rules

- Match an attachable `partial` class name to its `.cs` filename and Godot base type.
- Keep engine callbacks thin. Move rules and calculations into deterministic methods or plain data types when that improves direct testing.
- Sample collision and body movement in `_PhysicsProcess`; use `_Process` for frame-rate-dependent presentation and multiply continuous frame motion by `delta`.
- Export only designer-facing configuration. Use concrete types, defaults, ranges, groups, and units that prevent invalid Inspector input.
- Resolve required node references once in `_Ready`, inject them from the owning scene, or export typed node references. Do not perform repeated path lookups in hot callbacks.
- Prefer typed C# events for Godot signals. Unsubscribe in the matching lifecycle when using custom signals or capturing lambdas whose emitter can outlive the receiver.
- Use generated `MethodName`, `PropertyName`, and `SignalName` constants for dynamic Godot API calls when available.
- Remember that Godot vectors and other structs are copied by value in C#; modify a local and assign the whole value back.
- Avoid per-frame allocations, LINQ, unbounded searches, repeated native property access, and string-to-`StringName` conversions in measured hot paths.
- Do not add abstraction solely to enable mocking. First isolate a deterministic transform or pass the smallest controllable dependency.

Before relying on an unfamiliar API, query the connected editor's ClassDB. After C# changes, build assemblies before judging exports, signals, or editor-visible types.
