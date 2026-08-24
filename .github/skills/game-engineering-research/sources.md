# Curated Source Map

This is a navigation aid, not mandatory context. Prefer the current version of a source and verify engine APIs against the connected editor.

## Godot Primary Sources

- [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html): cohesive scenes, dependency injection, parent-mediated sibling relationships, and lifetime-oriented trees.
- [Scenes versus scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html): declarative composition versus imperative behavior.
- [Autoloads versus regular nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html): costs of global state/access and legitimate broad-scope services.
- [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html): `RefCounted` and `Resource` alternatives to lifecycle-heavy Nodes.
- [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html): typed data, serialization, Inspector integration, caching, and sharing semantics.
- [Version control systems](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html), [import process](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html), and [TSCN format](https://docs.godotengine.org/en/4.7/contributing/development/file_formats/tscn.html): generated `.godot/` state, source import metadata, and the structured text representation of scenes/resources.
- [ResourceUID](https://docs.godotengine.org/en/4.7/classes/class_resourceuid.html) and [UID changes in Godot 4.4](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/): stable resource references and source-adjacent script/shader UID sidecars.
- [Idle and physics processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html) and [physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html): fixed simulation ticks versus rendered frames.
- [General optimization](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html), [Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html), and [custom monitors](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/custom_performance_monitors.html): measure, isolate, optimize, and remeasure. The Godot profiler page notes that C# script profiling needs managed tooling such as Rider/dotTrace or Visual Studio.
- [C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html), [exports](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_exports.html), and [signals](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_signals.html): .NET prerequisites, engine interop, Inspector APIs, and signal lifetime details.

## Software And Test Evidence

- Politowski, Petrillo, and Guéhéneuc, [A Survey of Video Game Testing](https://arxiv.org/abs/2103.06431) (2021 preprint): surveys academic and gray literature; supports early, domain-tailored automation alongside human playtesting, and documents limits from coupling, randomness, volatility, and experiential requirements.
- Murphy-Hill, Zimmermann, and Nagappan, [How is video game development different from software development?](https://doi.org/10.1145/2568225.2568226) (ICSE 2014): empirical comparison of game and non-game development practices.
- Ampatzoglou and Stamelos, [Software engineering research for computer games: a systematic review](https://doi.org/10.1016/j.infsof.2010.05.004) (Information and Software Technology, 2010): maps game software-engineering research and its evidence gaps.
- Aleem, Capretz, and Ahmed, [Game development software engineering process life cycle: a systematic review](https://doi.org/10.1186/s40411-016-0032-7) (2016): process literature across pre-production, production, and post-production.
- Microsoft, [.NET unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices): fast, isolated, repeatable, self-checking tests; behavior-focused naming and Arrange-Act-Assert.

## Professional Engineering

- Git, [git-worktree](https://git-scm.com/docs/git-worktree), [git-merge](https://git-scm.com/docs/git-merge), and [git-rebase](https://git-scm.com/docs/git-rebase): worktree/ref boundaries, conflict resolution, and history-rewriting behavior.
- Git LFS, [project documentation](https://git-lfs.com/) and [locking](https://github.com/git-lfs/git-lfs/blob/main/docs/man/git-lfs-lock.adoc): external binary storage and optional single-writer locking; LFS does not make binary formats mergeable.
- Google Engineering Practices, [Small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html): small, focused changes as review and integration guidance.
- Brun et al., [Proactive Detection of Collaboration Conflicts](https://doi.org/10.1145/2025113.2025139) (ESEC/FSE 2011): collaboration includes higher-order build and behavior conflicts beyond textual overlap.
- Robert Nystrom, [Game Programming Patterns](https://gameprogrammingpatterns.com/): architecture for change, components, state, game loops, data locality, and explicit costs of patterns. Use as practitioner guidance, not universal prescription.
- Glenn Fiedler, [Fix Your Timestep](https://gafferongames.com/post/fix_your_timestep/): simulation stability, fixed timesteps, interpolation, headroom, and the spiral of death.
- Noel Llopis, [Data-Oriented Design](https://gamesfromwithin.com/data-oriented-design): design around data transformations and measured access patterns; includes modularity/testing benefits and adoption costs.
- Richard Fabian, [Data-Oriented Design](https://www.dataorienteddesign.com/dodbook/): deeper treatment of data flow, measurement, optimization, maintenance, and testing.
- Chris Simpson, [Behavior trees for AI: How they work](https://www.gamedeveloper.com/programming/behavior-trees-for-ai-how-they-work): production-oriented behavior tree contracts, traversal, context, and iterative fallbacks.
- GDC Vault, [Overwatch Gameplay Architecture and Netcode](https://www.gdcvault.com/play/1024001/Overwatch-Gameplay-Architecture-and-Netcode) by Timothy Ford, Blizzard (2017): a scale-specific ECS and deterministic network simulation case study.
- GDC Vault, [Animation Bootcamp: An Indie Approach to Procedural Animation](https://www.gdcvault.com/play/1020583/Animation-Bootcamp-An-Indie-Approach) by David Rosen, Wolfire (2014): procedural techniques for responsive animation with limited authored frames.

## Video And Talks

- Mike Acton, [Data-Oriented Design and C++](https://www.youtube.com/watch?v=rX0ItVEVjHc), CppCon 2014: reason from actual data and transformations; validate applicability to managed/Godot workloads before adopting low-level layouts.
- Timothy Ford, [Overwatch Gameplay Architecture and Netcode](https://www.youtube.com/watch?v=W3aieHjyNvw), GDC: production architecture and deterministic simulation at multiplayer-shooter scale.
- Martin Jonasson and Petri Purho, [Juice it or lose it](https://www.youtube.com/watch?v=Fy0aCDmgnxg): rapid demonstrations of presentation feedback affecting perceived game feel.
- Jan Willem Nijman, [The art of screenshake](https://www.youtube.com/watch?v=AJdEqssNZ-U), INDIGO Classes 2013: practical feedback and impact techniques; apply with accessibility controls and playtesting.

## Interpretation Rules

- Official documentation establishes supported behavior, not whether an architecture fits a game.
- Academic reviews establish trends and evidence gaps, not a turnkey workflow.
- Studio talks prove an approach worked under stated constraints, not that smaller games need the same machinery.
- Performance advice is incomplete without a local profile and target hardware.
- Automated tests establish functional contracts; players establish clarity, comfort, balance, and fun.