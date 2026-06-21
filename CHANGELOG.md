# Changelog

## Unreleased

Pre-release — not yet published to pub.dev. On-device visual verification still pending.

Initial development work (Phase 0 + Phase 1): the real-glass rendering engine and one flagship glass.

### Added
- `GlassContainer` widget that turns any child into glass, with an Impeller fragment-shader path and an
  automatic blur + tint fallback where custom shaders aren't supported.
- `shaders/glass.frag`: backdrop refraction, chromatic aberration, specular highlight, Fresnel rim, tint.
- `GlassMaterial` optical value object (with `copyWith` and `lerp`) and presets `GlassMaterials.liquid`
  and `GlassMaterials.clear`.
- Composable SDF-based shape model. `GlassShape` is now polymorphic — `roundedRect`, `circle`, and
  arbitrary `path` shapes — with `union` / `intersection` / `difference` combinators, so any silhouette
  (e.g. a bar with a punched hole) is `bar.difference(hole)`. `ShapeSdf` carries the matching primitives
  (`roundedRect`, `circle`) and boolean operators (`union`/`intersection`/`difference`/`smoothUnion`) —
  the executable twin of the shader's SDF.
- `SdfField` — bakes any `GlassShape`'s SDF into a grid and uploads it as a GPU-samplable image (RGBA8,
  normalised around an edge `spread`). The CPU half of the baked-SDF-texture render path that will let the
  GPU shader render arbitrary shapes (removing the current CPU fallback for non-rounded-rect shapes).
- `ShapeSdf.polygon` — the universal exact signed distance to any closed polygon (convex or concave).
  Sample any outline into vertices and the optics get a correct edge with no shape-specific code.
- `GlassShape.polygon` and `harmonicBlob` / `harmonicBlobShape` — a parametric harmonic-curve generator
  (a Fourier-perturbed circle) that produces smooth, seamless organic "blob" glass with a strict
  inner/outer radius bound and a seedable, deterministic outline. Blobs are fully-optical shapes (exact
  SDF), not approximations.
- The fallback renderer now draws its tint wash and Fresnel rim from the shape's exact silhouette, so the
  edge highlight follows any outline (including inner hole rims) instead of a hardcoded rounded rectangle.
  Shapes the analytic shader can't represent exactly route to this shape-accurate fallback rather than
  rendering a wrong silhouette.
- Pluggable, opt-in lighting: `ManualLightSource` (default), `PointerLightSource`, and
  `StreamLightSource` — physical-tilt support is opt-in via a stream, so `sensors_plus` is never a
  dependency.
- Runtime capability detection (`GlassCapabilities`, `resolveGlassRenderPath`) and a `GlassQuality` knob.
- `example/` gallery app for on-device visual verification.

### Notes
- Zero third-party runtime dependencies.
- The flagship `liquid` / `clear` glass is implemented; the wider catalogue of glass types is planned
  (see the README roadmap).
- Custom shapes currently render their full optics through the fallback path; giving the GPU shader the
  same any-shape SDF (via a baked signed-distance-field texture, or shape-op uniforms) is the next
  milestone so composed/arbitrary shapes also get full shader refraction.
