# Design Spec: `cins_glass_effects` — a real-glass rendering engine for Flutter

> Status: **Approved** 2026-06-20. Greenfield. This spec covers the whole product; each phase
> gets its own implementation plan. Phase 0 + Phase 1 are planned first.

## Context

Existing Flutter "glass"/glassmorphism packages stop at `BackdropFilter` blur + a translucent
tint. They never bend the real background, so they don't look like glass. The goal is a
**fully functional, easy-to-use package that turns any widget or custom shape into convincing,
physically-inspired glass** — refraction of the real backdrop, chromatic aberration,
tilt/light-responsive specular highlights, Fresnel edges, bevels, etc. — across mobile, tablet,
desktop, and (last) web.

**Feasibility is confirmed against the installed SDK.** Flutter **3.44 / Dart 3.12** ships
`ui.ImageFilter.shader(FragmentShader)` (`sky_engine/.../painting.dart:4479`), which runs a custom
fragment shader over the **backdrop** (backdrop bound as `sampler2D` index 0; first uniform must be
a `vec2` size). That is the exact primitive needed for true refraction + chromatic aberration of
real background content. It is **Impeller-only** (`ImageFilter.isShaderFilterSupported`; throws
`UnsupportedError` otherwise) → mobile/desktop get the full shader path, **web needs a blur+tint
fallback** (hence "web last"). Known gotcha: OpenGL-ES backends flip the shader Y axis.

### Locked decisions
- **v1 must refract the real backdrop** (the hard, differentiating look).
- **Depth-first**: build the engine + one flagship glass before scaling the catalogue.
- **API**: both a wrap-any-widget container AND a raw shape/path API.
- **Light/tilt is opt-in and pluggable** — default manual (zero deps), pointer built-in, gyro via
  an adaptor so `sensors_plus` is never forced (RAM-conscious).
- **Single package now**, structured modularly; revisit multi-package split + tree-shaking in Phase 4.

## Core architectural insight

There is **one rendering primitive, not sixteen**. A glass widget =
*clip to a `ShapeBorder`/`Path`* → *`BackdropFilter` running one parameterized `glass.frag`* →
*optional painted overlays*. Each named glass "type" is a **preset** (`GlassMaterial`) that supplies
uniforms + an optional height/normal map to that single shader. Types differ in **parameters, not code**.

Enabling trick for arbitrary shapes: at paint time, derive a **signed-distance field (SDF) / thickness
field from the shape**. Distance-to-edge drives Fresnel, edge-thickness gradient, rim light, bevel,
and stronger refraction near edges — so glass looks correct on *any* shape, not just rectangles.

## Layered architecture

1. **Geometry layer** — `ShapeBorder`/`Path` → clip region + SDF/thickness field (+ surface normal
   from SDF gradient and/or a supplied normal map).
2. **Optics shader** (`shaders/glass.frag`) — samples backdrop and composes: refraction offset,
   per-channel chromatic aberration, specular highlight (light/tilt dir · normal), Fresnel rim,
   tint, blur/roughness. One shader, many uniforms. Handles GLES Y-flip.
3. **Material / presets** — `GlassMaterial` immutable value object holding all uniforms + optional
   maps + flags. Named glasses are factory presets (`GlassMaterial.liquid`, `.frosted`, `.reeded`,
   `.crystalline`, `.smoked`, `.acrylic`, …).
4. **Widget layer** — `GlassContainer({child, material, shape})` wrapper; `GlassPaint`/`Glass.shape`
   for raw `Path`/`ShapeBorder`; `GlassLightSource` controller (`ManualLightSource` default,
   `PointerLightSource`, `GlassLightSource.fromStream` adaptor for opt-in gyro).
5. **Capability layer** — runtime `ImageFilter.isShaderFilterSupported` → shader path vs blur+tint
   fallback; `GlassQuality` enum to scale cost (sample counts, blur passes) per device.

### Effect → mechanism coverage (full list, no gaps)
- Refraction, parallax, edge-thickness → backdrop sample offset from SDF + normal/height map.
- Chromatic aberration → per-RGB-channel sample offset.
- Specular / anisotropic / tilt-responsive highlights, rim lighting → light-dir · surface normal.
- Fresnel, 3D look, bevel, emboss/deboss → SDF distance + normal-based shading.
- Frosted, grain/noise, smoked/tint, opaque, acrylic → blur + tint + noise (also the **web fallback**).
- Sharp/rounded borders → `ShapeBorder`.
- Caustics, total internal reflection, subsurface (faked), holographic/iridescent, wet/condensation,
  crystalline/faceted, bubble, stained → advanced shader terms + presets (later phases).
- Camera-mirror effect → explicitly deferred / out of scope for now (permissions + plugin).

## Package structure (single package)

```
lib/
  cins_glass_effects.dart        # barrel: re-exports public API
  src/
    geometry/   shape_sdf.dart, glass_geometry.dart
    optics/     glass_render_object.dart, capability.dart, quality.dart
    materials/  glass_material.dart, presets.dart
    light/      glass_light_source.dart  (manual, pointer, fromStream)
    widgets/    glass_container.dart, glass_paint.dart
shaders/
  glass.frag                     # declared under flutter: shaders: in pubspec
example/                         # gallery app = visual/screenshot test harness
test/                            # unit + widget tests (non-shader logic)
```

Shaders compile via the standard pipeline (`flutter: shaders:` key in `pubspec.yaml` +
`FragmentProgram.fromAsset`) — **no extra runtime dependency**. Core aims for **zero runtime deps**;
`sensors_plus` is never a core dependency (opt-in by the app via the stream adaptor).

## Phasing (depth-first)

- **Phase 0 — scaffold:** package layout above; pubspec `shaders:` wiring; `example/` gallery app;
  `capability.dart` + `GlassQuality`; test harness.
- **Phase 1 — flagship (the proof):** `ShapeSDF` from `ShapeBorder`/`Path`; `glass.frag` with
  refraction + chromatic aberration + specular + Fresnel + tint; `GlassContainer` + raw shape API;
  `ManualLightSource` + `PointerLightSource`; **one stunning Clear/Liquid preset** on mobile
  (Impeller); blur+tint fallback when unsupported. Validate on a real device via the gallery app.
- **Phase 2 — catalogue:** add presets (Frosted, Acrylic, Smoked, Reeded/Textured, Crystalline,
  Neumorphic, Beveled) — mostly parameter + height/normal-map work, little new code.
- **Phase 3 — depth & desktop:** pointer-driven light polish on desktop; advanced optics
  (caustics, iridescent/holographic, wet/condensation, faked subsurface, anisotropic).
- **Phase 4 — web & scale:** web fallback fidelity + perf budget; decide multi-package split +
  tree-shaking strategy now that the real surface area is known.

## Key risks / honest caveats
- **No shader output in headless `flutter test`.** `ImageFilter.shader` needs Impeller, which the
  widget-test environment doesn't run. Shader *visuals* can't be golden-tested in CI; validation is
  via the example app on device + `integration_test`/driver screenshots. Unit/widget tests cover the
  testable logic instead (see Verification).
- **Performance:** backdrop-sampling shaders + blur are GPU-heavy; reuse `backdropId` for repeated
  glass (list items), expose `GlassQuality`, and measure on a mid-range device early.
- **Web:** real refraction is not available; the fallback must look intentional, not broken.
- **GLES Y-flip** must be handled in the shader or Android-on-GL renders upside down.

## Verification
- **Unit tests** (`flutter test`): `ShapeSDF` distance/normal math; `GlassMaterial` preset values &
  `copyWith`/lerp; capability→path selection; `GlassLightSource` outputs.
- **Widget tests**: `GlassContainer` builds, clips to the shape, and falls back to blur+tint when
  `isShaderFilterSupported` is false (injected/mocked).
- **Visual / on-device** (the real fidelity check): run `example/` gallery on an Impeller device
  (`flutter run`), eyeball each glass type, capture screenshots; optionally `integration_test`
  driver screenshots.
- Keep `flutter analyze` clean throughout.

## Out of scope (for now)
Camera-based mirror/reflection glass; multi-package split (Phase 4 decision); shipping every one of
the 16 types in v1 (Phase 1 ships one flagship; the rest follow as presets).
```
