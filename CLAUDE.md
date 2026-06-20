# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`cins_glass_effects` is a Flutter **package** (a reusable library, not a runnable app) intended
for publication to pub.dev. Its goal is to **realistically mimic real glass** as a set of drop-in
Flutter widgets — not flat translucency, but physically-inspired refraction, shaders, chromatic
aberration, and specular highlights. A camera-based mirror/reflection effect is under consideration.

**Current state: greenfield / pre-implementation.** The repo was scaffolded with
`flutter create --template=package`. The generated placeholder `Calculator` and its test have been
removed; `lib/cins_glass_effects.dart` is the (currently empty) public barrel. No effects exist yet
— the first real work is a brainstorming/planning session to define the architecture.

The README's "Planned" list captures the intended catalogue: Opaque, Frosted, Clear/Glass,
Smoked/Tinted, Textured/Reeded, Liquid Glass, Frosted-with-Grain, Crystalline/Faceted,
Wet Glass/Condensation, Neumorphic Glass, Beveled, Holographic/Iridescent, Specular/Glossy,
Bubble, Stained, Acrylic.

## Target stack

- **Flutter 3.44 / Dart 3.12.**
- Visual fidelity is the point. Expect heavy use of `dart:ui` primitives and **fragment shaders**
  (`FragmentProgram` / `.frag` via `ShaderMask`, `BackdropFilter`, `ImageFilter`, `CustomPainter`)
  to achieve refraction, chromatic aberration, and specular highlights.

## Platform strategy (priority order)

1. **Mobile + tablet** (primary target).
2. **Desktop / laptop** (secondary).
3. **Web** (last).

Aim for all platforms. Where a single implementation can't deliver the effect everywhere, it is
acceptable to use **native-code plugins or platform-specific code paths** per device class —
pick the implementation per platform rather than lowest-common-denominator everywhere.

## Open architectural questions (resolve in brainstorming, don't assume)

- Whether to ship as **one package or several** (e.g. core vs. per-effect or per-platform packages).
- **Tree shaking** so apps only pay for the effects/shaders they actually use.
- How camera-based mirror effects fit in (permissions, platform support, optional dependency).

## Commands

```bash
flutter pub get          # install dependencies
flutter test             # run all tests
flutter test test/<file>_test.dart               # run a single test file
flutter test --name "<test name>"                # run a single test by name
flutter analyze          # static analysis (lints from flutter_lints)
dart format .            # format
```

There is no app to run — verify work through `flutter test` / widget tests, not by launching.

## Conventions

- **Single barrel export:** `lib/cins_glass_effects.dart` is the package's entire public API surface.
  Implement effects under `lib/src/…` and re-export public types from the barrel; anything not
  re-exported is package-private.
- **Tests** in `test/`, mirroring `lib/`, using `package:flutter_test` (`testWidgets` / `WidgetTester`
  for widget effects).
- **Lints:** `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`; keep
  `flutter analyze` clean.
- No third-party runtime dependencies are declared yet — adding one (or a shader asset) is a
  deliberate decision; prefer framework/`dart:ui` primitives first.
