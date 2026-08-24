---
name: "Godot Scenes and Resources"
description: "Use when creating or editing Godot scenes, nodes, Resources, project settings, input actions, autoloads, collision setup, or serialized .tscn/.tres data."
applyTo: ["**/*.tscn", "**/*.tres", "project.godot"]
---
# Scenes And Resources

- Prefer Godot editor or Godot AI MCP operations over manual serialized-text edits.
- Give a reusable scene everything it needs internally. When external context is required, let the owner inject a typed reference or connect a signal.
- Use parent-child structure for lifetime ownership: deleting a parent should reasonably delete its children. Let a common ancestor coordinate siblings.
- Use scenes for reusable node composition and Resources for typed, serializable, Inspector-editable data. Use plain C# data for transient rules that need no Godot lifecycle or serialization.
- Keep shared Resources immutable at runtime or duplicate them deliberately; loaded Resources are cached and may be shared by multiple consumers.
- Use autoloads only for truly broad, self-contained state or services. Do not use global access to avoid defining ownership.
- Prefer explicit input actions over raw keys. Preserve keyboard, controller, remapping, and dead-zone semantics where the feature requires them.
- Assign collision layers and masks intentionally. Validate both sides of an intended collision or detection relationship.
- Use `snake_case` for non-C# files and folders, `PascalCase` for C# files and node names, and exact path casing for export portability.
- Review scene diffs for rewritten resource IDs, ownership changes, embedded-resource duplication, and unrelated editor churn.

After structural edits, save the scene, inspect its hierarchy and required properties, run the affected scene, and check fresh editor/runtime errors.