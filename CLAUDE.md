# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`cins_glass_effects` is a Flutter **package** (a reusable library, not a runnable app) intended
for publication to pub.dev. Its goal is to **realistically mimic real glass** as a set of drop-in
Flutter widgets — not flat translucency, but physically-inspired refraction, shaders, chromatic
aberration, and specular highlights. A camera-based mirror/reflection effect is under consideration.

**It is a glass *engine*, not a shape/component catalogue.** The user brings the shape (their widget,
a custom `Path`, a generated blob); the package turns *that* shape into glass. We do **not** enumerate
shapes. The README's "glass types" (Frosted, Reeded, Crystalline, Holographic, Bubble, embossing/
debossing, …) are **materials / surface treatments** — parameter sets over the same engine — not
hardcoded geometry.

**Current state: working engine, pre-release (unpublished).** Implemented: `GlassContainer`, the
`shaders/glass.frag` + `glass_sdf.frag` optics shaders, the `GlassMaterial` model + `liquid`/`clear`
presets, opt-in lighting, capability detection, the SDF-driven shape system below, and the
baked-SDF-texture path (any shape with an SDF gets full shader optics on Impeller; on-device visual
verification pending). The wider material catalogue and true-3D surface are still to build (see
Roadmap in README / `WORKLOG.md`).

## Core architecture — the SDF *is* the shape API

Every optical effect in `shaders/glass.frag` (refraction direction, edge band, Fresnel, specular,
mask) is derived from **one signed-distance value `d` and its gradient**. So a shape only has to report
its **signed distance field** and the optics follow it exactly — any silhouette, no per-shape code.

- `ShapeSdf` — pure-Dart SDF primitives (`roundedRect`, `circle`), boolean ops
  (`union`/`intersection`/`difference`/`smoothUnion`), and `polygon` (exact SDF for *any* closed
  polygon). This is the executable twin of the GLSL SDF — **keep the two in lockstep.**
- `GlassShape` — polymorphic: `roundedRect`, `circle`, `polygon`, arbitrary `path`, plus
  `union`/`intersection`/`difference` combinators. Each exposes `clipPath(size)` + `sdf(p, size)`.
- `shape_generators.dart` — maths that *generate* geometry (e.g. `harmonicBlob`, a Fourier-perturbed
  circle) → vertices → `GlassShape.polygon` (exact SDF, fully-optical).

### Two shaders, one optics core — and the no-fallback rule

A fragment shader is compiled GLSL with **fixed-size uniforms**; it can't accept a variable-length
polygon or an arbitrary Dart function. So there are two shader variants with an identical optics core
(**keep them in lockstep**): `glass.frag` computes `sdRoundedBox` analytically; `glass_sdf.frag` reads
`d` from a **baked SDF texture** (sampler 1; the engine binds the backdrop to sampler 0). `SdfField`
bakes any `GlassShape.sdf` into that texture; `SdfTextureCache` owns one bake per (shape, size) and
serves a stale texture during resizes so glass never flashes back to the fallback.

**Backdrop geometry gotcha (verified in Impeller source):** a backdrop filter's input texture is the
**whole render pass** (screen) — the clip only bounds the output. So both shaders take the widget's
rect as uniforms (`uRectOrigin`/`uRectSize`, device px), injected at paint time by `GlassBackdrop`
(custom render object, `localToGlobal × dpr`). Never derive shape geometry from `uSize` — it's the
snapshot size, not the widget size.

- **Shape math — never falls back, and is complete.** Every closed shape has an exact SDF.
- **The blur+tint fallback remains only for**: backends without `ImageFilter.shader` (web, currently
  desktop), and `GlassShape.path` without an `sdfFn` (`hasSdf == false`). Treat any *math*-level
  fallback as a bug. On Impeller, every shape with an SDF gets full shader optics.

### Next axis (not built): true 3D

Glass must mimic 3D even when thin. Plan: user-defined **thickness** + a **bevel/height profile `h(d)`**
over the SDF (the edge band already yields the inward normal); **emboss/deboss** = an interior feature
SDF that modulates that height field. Framing: "CSS for Dart, but for glass only."

## Target stack

- **Flutter 3.44 / Dart 3.12.**
- Visual fidelity is the point. Expect heavy use of `dart:ui` primitives and **fragment shaders**
  (`FragmentProgram` / `.frag` via `ShaderMask`, `BackdropFilter`, `ImageFilter`, `CustomPainter`)
  to achieve refraction, chromatic aberration, and specular highlights.

## Platform strategy (priority order)

1. **Android** (primary).
2. **iOS** (second).
3. **Windows / Linux** (third).
4. **Web** (last, only if possible).

Aim for all platforms. Where a single implementation can't deliver the effect everywhere, it is
acceptable to use **native-code plugins or platform-specific code paths** per device class —
pick the implementation per platform rather than lowest-common-denominator everywhere.

## Open architectural questions (don't assume)

- Whether to ship as **one package or several** — splitting into core + plugins/packages is acceptable
  if it's what lets the user make any glass type in the README.
- **Tree shaking** so apps only pay for the effects/shaders they actually use.
- How camera-based mirror effects fit in (permissions, platform support, optional dependency).

## Verification

Primary verification is `flutter test` / widget tests. An `example/` gallery app exists for on-device
**visual** checks (the optics shader needs Impeller and can't be unit-tested), but logic/geometry is
verified by tests, not by launching.

## Conventions

- **Single barrel export:** `lib/cins_glass_effects.dart` is the package's entire public API surface.
  Implement effects under `lib/src/…` and re-export public types from the barrel; anything not
  re-exported is package-private.
- **Tests** in `test/`, mirroring `lib/`, using `package:flutter_test` (`testWidgets` / `WidgetTester`
  for widget effects).
- No third-party runtime dependencies are declared yet — adding one (or a shader asset) is a
  deliberate decision; prefer framework/`dart:ui` primitives first.
