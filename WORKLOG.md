# Worklog

## 2026-07-13 — Root-caused the on-device wash-out: backdrop input = whole screen

- Hanna's Pixel screenshot showed the baked-SDF nav bar washed-out/glowing and the analytic panel
  with tint+frost but **no edge optics** — one hypothesis explained both, confirmed by reading the
  Impeller source (`canvas.cc`, `runtime_effect_filter_contents.cc`): **a backdrop filter's input
  texture is the entire render pass (screen), not the clip bounds**; `uSize`/`FlutterFragCoord` are
  in that snapshot's space. Both shaders were drawing the shape over the whole screen; the clip only
  hid the evidence off-widget (this also retro-explains the very first "no blur on Android" run).
- Fix: shaders take `uRectOrigin`/`uRectSize` (device px); new `GlassBackdrop`
  (`SingleChildRenderObjectWidget` + `RenderProxyBox`) rebuilds the filter **at paint time** with
  `localToGlobal × dpr` — the only moment the true position is known. Known limits (documented):
  assumes no ancestor rotation/scale and the pass starting at the screen origin; glass inside a
  scrollable can lag a frame if paint is skipped.
- Also confirmed: the `ImageFilter.compose(blur, shader)` engine bug (flutter#170820) was fixed
  Oct 2025 (PR #177687), so batch 1's frost compose is safe on 3.44.
- Builders got a `debugSetUniforms` seam so tests set *all* uniforms (incl. rect) on the real
  compiled shaders; new `glass_backdrop_test` proves the device-rect maths. 75 tests green.
- **On-device re-check:** panel should now show fresnel rim + specular + edge refraction; the nav
  bar should read as glass with a defined rim and a correct hole edge around the FAB.

## 2026-07-13 — Batch 2: baked-SDF shader path — custom shapes get full optics

- `glass_sdf.frag`: second shader variant, optics core identical to `glass.frag` (lockstep!), but `d`
  is decoded from a baked SDF texture (sampler 1; engine binds backdrop to sampler 0). Gradient via
  finite differences on the field; `uSdfRange` carries spread × devicePixelRatio so distances stay in
  the same pixel units as the analytic shader.
- `GlassSdfFilterBuilder` (same one-shader-per-lifetime contract), `GlassMaterial.toSdfShaderFloats`,
  `GlassShape.hasSdf`, and `SdfTextureCache` (bake once per shape+size, supersede in-flight bakes,
  serve stale texture during resize — no fallback flash).
- `GlassContainer` now routes: analytic shader (rounded rect) → baked-SDF shader (anything with an
  SDF) → fallback (no shader support, or path without `sdfFn`). Size discovered post-frame via
  `context.size` inside a `LayoutBuilder` (constraint changes retrigger measurement).
- Fixed latent `PathShape` equality bug: a stable `id` now decides equality as documented — without
  this, fresh closures each build would have re-baked the texture every frame.
- Tests compile `glass_sdf.frag` for real in `flutter test` and exercise packing/cache/equality
  (73 passing). **On-device check pending:** polygon/blob/nav-bar-hole shapes should now show
  refraction + specular on the Pixel; verify edge-band width matches the analytic path (dpr scaling)
  and that sampler-1 binding works with `ImageFilter.shader`.

## 2026-07-13 — Optics batch 1: shader reuse, real frost on Impeller, GLES flip in-shader

- External review triaged (~70% right): confirmed shader-per-frame allocation + missing shader-path
  blur as the real bugs; rejected its premultiplied-alpha "fix" (a mathematical no-op) and its
  squircle formula (an implicit function, not an SDF — would distort the edge band).
- `GlassFilterBuilder`: one `FragmentShader` per builder lifetime, uniforms updated in place,
  `dispose()` added and called from `GlassContainer.dispose`. New tests compile the real shader
  asset in `flutter test` (bare asset key inside the package), proving GLSL/Dart uniform lockstep.
- Shader path now frosts: `blurSigma` composed under the optics filter (`ImageFilter.compose`),
  explaining the observed "Windows blurs, Android doesn't" — Android took the shader path, which
  had no blur. Needs on-device re-check.
- `GlassLight.intensity` wired (`uIntensity` × specular/Fresnel); `flipY` param deleted — GLES flip
  is now `#ifdef IMPELLER_TARGET_OPENGLES` in `glass.frag` (engine-defined, documented in `dart:ui`).
- Confirmed in `dart:ui` docs that `ImageFilter.shader` allows extra samplers ("at least one…") —
  the baked-SDF-texture milestone is API-viable as designed; it's the next batch.
- Housekeeping: capabilities detected once per state; fallback `+6` named `_fallbackBlurBoost`;
  example got `flutter_lints` so `flutter analyze` is clean repo-wide.

## 2026-06-21 — Real glass nav bar fixture + baked-SDF baker (toward no GPU fallback)

- **Glass nav bar test** (`test/widgets/glass_nav_bar_test.dart`): rebuilt subscription_tracker's bottom
  bar from this package's primitives, with the *exact* dimensions (bar 58, FAB 70, hole r=43, corner 29,
  nav icon 28, FAB icon 47.6, middle gap 118). Confirms the custom-shape need: the FAB is larger than the
  bar and centred, so the bar uses `roundedRect(29).difference(circle r=43)` — Material's notch can't do an
  oversized centred through-cut. Geometry asserts the hole is carved (incl. that r=43 > half-height 29 cuts
  clean through) and the rim sits at d≈0; widget test renders bar + 4 items + centred FAB.
- **`SdfField` baker** (`lib/src/optics/sdf_field.dart`): samples any `GlassShape.sdf` into a grid, encodes
  the signed distance to RGBA8 (normalised around a `spread` band where the optics live), and uploads a
  `ui.Image`. This is the CPU half of the baked-SDF-texture path that lets the GPU shader sample `d` for an
  arbitrary shape — the fix that deletes the render fallback. Fully unit-tested (grid matches exact SDF,
  square texels, sign, hole baked, encode/decode round-trip, edge≈0.5, image dims).
- **Why baker first:** shaders can't be unit-tested (need Impeller), but the baker can be — so the
  verifiable engine work lands now; wiring `glass.frag` to sample the texture (2nd sampler + a branch,
  gated so the working rounded-rect path is untouched) is the remaining step, to be validated on-device.

## 2026-06-21 — Universal polygon SDF + harmonic-blob generator

- **Why:** stress-test clipping/SDF with non-trivial shapes, and close the "no analytic SDF" gap so
  there's no *math* fallback — only the (separate) GPU-plumbing gap remains.
- **Reframe:** the shape math never needs a fallback — *every* closed shape has an exact SDF (signed
  distance to a polygon). The only remaining fallback is the GPU shader not yet sampling an arbitrary
  SDF; the fix for that is a baked SDF texture (next milestone), not a custom engine.
- Added `ShapeSdf.polygon` (Inigo Quilez's exact polygon SDF — handles concavity).
- Added `harmonicBlob` / `harmonicBlobShape`: a parametric harmonic curve (Fourier-perturbed circle).
  Integer frequencies ⇒ seamless closure; amplitude-sum normalisation ⇒ radius strictly within
  [inner, outer]; seedable ⇒ deterministic for tests. Wrapped as a fully-optical `GlassShape.polygon`.
- Tests: polygon SDF (inside/edge/outside + concave notch), blob bounds/seam/determinism, blob SDF vs
  clip containment, and a no-sharp-corner check on the outline. 49 pass, analyze clean.
- **Next axis (design, not yet built):** 3D — user-defined thickness + a bevel/height profile h(d) over
  the SDF (the edge band already gives the inward normal), and emboss/deboss as an interior feature SDF
  that modulates that height field. Plus the GPU baked-SDF texture so arbitrary shapes get full shader
  refraction (deletes the render fallback).

## 2026-06-21 — SDF-based shape model (any-shape glass, stage 1)

- **Why:** tests (and the API) were rounded-rect-only, so we couldn't tell how custom shapes — e.g.
  `subscription_tracker`'s bar-with-a-hole nav bar — would be handled. The package must turn *any*
  silhouette into glass, not ship a shape catalogue.
- **Key realisation:** the shader derives *every* optical effect (refraction, edge band, Fresnel,
  specular, mask) from one SDF value + its gradient. So the signed-distance field is the universal
  interface to any shape; boolean SDF ops (`min`/`max`) compose primitives with exact edges.
- Generalised `ShapeSdf` from one function into composable primitives (`roundedRect`, `circle`) +
  boolean operators (`union`/`intersection`/`difference`/`smoothUnion`).
- Made `GlassShape` polymorphic and SDF-backed: `roundedRect`, `circle`, arbitrary `path`, plus
  `union`/`intersection`/`difference` combinators. Bar-with-hole is now `bar.difference(hole)`.
- Removed the rim tradeoff on the fallback path: `GlassFallbackOverlay` strokes the shape's exact
  silhouette, so the edge highlight follows any outline (incl. hole rims).
- Honest routing: only shapes the analytic shader can render exactly (`shaderRepresentable`) use the
  GPU path; everything else uses the now shape-accurate fallback — never a wrong silhouette.
- Tests: SDF primitives + ops, `GlassShape` geometry (roundedRect/circle/path), and a flagship
  bar-with-hole verified as both geometry (SDF carves the hole, rim at d≈0) and a live widget. 39 pass,
  `flutter analyze` clean.
- **Next:** give the GPU shader the same any-shape SDF (baked distance-field texture or shape-op
  uniforms) so composed/arbitrary shapes get full shader refraction, not just the fallback.
