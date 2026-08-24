---
name: "Review Game Change"
description: "Independently review current Godot game changes for behavioral regressions, lifecycle and timing defects, scene risks, and missing validation."
argument-hint: "Claimed behavior or files to review"
agent: "Gameplay Reviewer"
---
Review the requested change or current working-tree diff. Run the narrowest available checks, exercise the affected runtime behavior through Godot AI when possible, and report findings before summary.

Remain read-only. Do not fix findings in this review pass.