---
name: game-feature-loop
description: "Implement or fix a Godot game feature through a thin vertical slice: acceptance criteria, local hypothesis, minimal edit, automated checks, live runtime inspection, and independent review. Use for gameplay mechanics, UI flows, controls, physics, AI, animation, audio, save systems, or bug fixes."
argument-hint: "Feature, bug, or gameplay behavior"
---
# Game Feature Loop

Use [the validation skill](../godot-validation/SKILL.md) for the evidence ladder. Use `game-engineering-research` only when a concrete unknown blocks the next check.

## 1. Define The Slice

Write one player-observable outcome and 2-5 acceptance criteria. Include relevant boundaries:

- initial state and exact input or event;
- expected state transition or output;
- timing/tick constraints;
- collision, camera, UI, audio, persistence, or accessibility effects;
- explicit non-goals.

For a bug, capture a minimal reproduction before editing. For subjective feel, define measurable proxies but reserve final judgment for playtesting.

When work may run in parallel, also declare:

- base commit and private worktree branch;
- owned scene, script, resource, test, and asset paths;
- shared contracts consumed or changed;
- dependencies and expected integration order.

The parent coordinator must acknowledge this reservation against the complete active reservation table before editing starts. If another worktree owns a required file, request an exact change or sequence the work; do not create a second writer. Ask the coordinator before expanding the owned path set.

## 2. Trace Ownership

Inspect only the scene, script, resource, signal, and input action that control the behavior. Identify:

- who owns state and lifetime;
- who samples input;
- who advances simulation;
- who presents feedback;
- the nearest existing test or runtime observable.

Prefer ownership of one cohesive vertical unit. When parallel work is expected, extract or reuse self-contained child scenes/resources rather than making unrelated agents save the same parent scene. Do not introduce that extraction solely to avoid one small sequential edit.

State one falsifiable hypothesis and the cheapest check that can reject it. Then edit.

## 3. Implement Vertically

- Make one behavior-sized change that reaches a runnable state.
- Keep rules deterministic where practical; keep Godot callbacks as adapters.
- Use Resources/exports for designer-tuned data and constrain invalid values.
- Preserve scene ownership and existing public contracts.
- Do not generalize for hypothetical future features.

## 4. Validate Immediately

Run the narrowest check after the first edit. If it fails, repair the same behavior before widening scope.

Then validate the complete slice:

1. compile or diagnostics;
2. focused logic or scene test;
3. affected scene launch;
4. controlled input and runtime state inspection;
5. fresh error logs;
6. screenshot/visual inspection when presentation changed;
7. baseline comparison when performance changed.

Test at a second frame rate, physics tick, input device, resolution, or content configuration only when the feature depends on it.

## 5. Review And Report

Review behavior before style. Check state invariants, lifecycle cleanup, event subscriptions, frame dependence, invalid exported data, resource sharing, and accidental scene churn.

Before handoff, compare the actual diff with declared ownership. Identify shared API, signal, export, input-action, resource-path, or scene-contract changes that dependent worktrees must absorb.

Run `git status --short` and `git diff --check`, include untracked paths in the ownership comparison, create a focused result commit, and confirm the worktree is clean. Do not hand off unstaged or uncommitted implementation state.

Report:

- behavior delivered;
- base/result commits, touched paths, and integration dependencies when work is handed off;
- checks run and outcomes;
- unverified experiential or platform concerns;
- only the next action needed, if any.
