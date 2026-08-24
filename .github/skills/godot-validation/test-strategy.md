# Test Strategy

Choose tests by failure cost and feedback speed, not a coverage quota.

| Layer | Best for | Avoid |
|---|---|---|
| Pure logic | state transitions, formulas, inventory/rules, seeded generation | Nodes, files, clocks, global input |
| Node/component | lifecycle, signals, local physics contracts, exported configuration | loading the whole game |
| Scene contract | required children/resources/groups, wiring, collisions, startup | long player journeys |
| Runtime journey | input-to-outcome behavior across systems | exhaustive branches |
| Visual/performance | rendering regressions, layout, frame budgets, spikes | subjective fun claims |
| Human playtest | feel, clarity, comfort, accessibility, balance, fun | repetitive functional regression |

## Test Qualities

- Fast, isolated, repeatable, self-checking, and behavior-focused.
- One reason to fail and at least one meaningful assertion.
- Names describe behavior, scenario, and expected result.
- Control time, randomness, inputs, and initial state. Record seeds for reproduced failures.
- Assert public outcomes and invariants rather than private implementation or exact node layout unless layout is the contract.
- Use the smallest fixture. Clean up nodes, events, temporary files, and global state.
- Prefer boundary and transition cases over many similar examples.
- Coverage is a navigation signal, not proof of test quality.

## Godot AI Test Runner

The installed plugin discovers `res://tests/test_*.gd`. Suites extend:

```gdscript
extends "res://addons/godot_ai/testing/test_suite.gd"

func suite_name() -> String:
	return "movement"

func test_example_contract() -> void:
	var actual := 2 + 2
	assert_eq(actual, 4)
```

Use `setup`, `teardown`, `suite_setup`, and `suite_teardown` only for state genuinely shared at that scope. Register manually managed objects with `track`. The runner treats a passing test with zero assertions as a failure and returns structured, filterable results.

Use this runner for editor/scene integration. Use an existing .NET test project for pure C# logic if present. Do not force all tests through one framework.

## Regression Rule

For a fixed bug, add the cheapest stable test that fails for the original cause. If automation would be brittle or cannot observe the failure, record a short deterministic reproduction and the runtime evidence used instead.