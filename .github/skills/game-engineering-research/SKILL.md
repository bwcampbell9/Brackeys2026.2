---
name: game-engineering-research
description: "Research game programming and Godot engineering decisions using official documentation, academic literature, professional postmortems/blogs, GDC talks, and verified runtime evidence. Use for unfamiliar engine APIs, architecture choices, physics, AI, networking, performance, testing strategy, or disputed best practices."
argument-hint: "Question, subsystem, or decision to research"
---
# Game Engineering Research

Use research to resolve a decision, not to accumulate general facts. Read [sources.md](./sources.md) only for the relevant topic.

## Procedure

1. **Frame the decision.** Write the concrete question, constraints, target Godot version/platform, and what observation would change the answer.
2. **Inspect locally.** Find the owning code path, scene, configured engine version, existing conventions, current failure or baseline, and any active worktree that owns overlapping files or contracts.
3. **Query the engine.** Use Godot AI ClassDB/API inspection for signatures and capabilities in the connected editor. Prefer it over remembered APIs.
4. **Collect evidence in order:**
   - current official Godot and .NET documentation;
   - peer-reviewed work or a transparent literature review;
   - first-party studio talks, postmortems, and engineering publications;
   - reputable practitioner material with reproducible reasoning;
   - forums and snippets only as leads to verify elsewhere.
5. **Triangulate.** Seek at least two independent source classes for consequential claims. Check publication date, engine version, platform, workload, and whether advice is measured or anecdotal.
6. **Test locally.** Build the smallest probe that can falsify the leading option. Prefer a unit test, isolated scene, controlled input sequence, profiler capture, or ClassDB query.
7. **Decide.** Choose the smallest option supported by local constraints and evidence. Record tradeoffs and rejected alternatives only when they may recur.
8. **Validate after implementation.** Compare the same observable against the baseline and acceptance threshold.

For research intended to guide parallel implementation, recommend ownership boundaries, dependency order, integration checks, and which shared files require a single integration owner. Distinguish official file-format/version-control facts from conflict-reduction heuristics.

## Evidence Notes

Keep the working note compact:

```text
Decision:
Constraints:
Evidence:
- [source, date/version] claim and applicability
Local check:
Result:
Choice:
Uncertainty:
```

Distinguish these claim types:

- **API fact:** directly supported by current official docs or ClassDB.
- **Measured result:** includes workload, hardware/platform, baseline, and metric.
- **Design heuristic:** useful guidance with contextual tradeoffs, not a law.
- **Experiential claim:** requires human playtesting; automation can guard regressions but cannot prove fun or feel.

## Context Discipline

- Load only sources relevant to the active decision; summarize, then discard raw excerpts.
- Link to a source instead of copying long passages.
- Do not turn one studio's scale-specific architecture into a default pattern.
- Stop when one option is clearly supported and a local check can discriminate it. More reading after that point delays evidence.
- If sources disagree, report the disagreement and choose based on this project's measured constraints.
