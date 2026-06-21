# Worklog

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
