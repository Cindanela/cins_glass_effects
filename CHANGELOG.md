# Changelog

## Unreleased

Pre-release — not yet published to pub.dev. On-device visual verification still pending.

Initial development work (Phase 0 + Phase 1): the real-glass rendering engine and one flagship glass.

### Added (baked-SDF shader path)
- `shaders/glass_sdf.frag` + `GlassSdfFilterBuilder`: the same optics as the analytic shader, but
  the silhouette comes from a baked signed-distance texture — so **any shape with an SDF (circles,
  polygons, blobs, boolean cut-outs) now gets full shader fidelity on Impeller** instead of the
  blur+tint fallback. The fallback remains only for non-Impeller backends and `GlassShape.path`
  without an `sdfFn`.
- `SdfTextureCache`: bakes once per (shape, size), supersedes stale in-flight bakes, and keeps the
  previous texture available during resizes so glass never flashes back to the fallback.
- `GlassShape.hasSdf`: whether a shape's SDF is evaluable (false only for `GlassShape.path` without
  `sdfFn`, and boolean combos touching one).
- `GlassShape.path`: a stable `id` now *decides* equality, as its docs always promised — fresh
  builder closures per build no longer re-clip (or re-bake) every frame.

### Fixed
- Staircase edges on baked shapes: the baked-SDF shader no longer draws its own silhouette mask
  (the `ClipPath` already cuts an exact anti-aliased outline); the field only drives the optics.
  Bake density doubled to ~2 texels per logical px (cap 512).
- **Both shader paths rendered the shape over the whole screen** instead of the widget. Root
  cause (verified in the Impeller engine source): a backdrop filter's input texture is the whole
  render pass — the clip only bounds the output — so `uSize`-derived geometry was screen-sized.
  On device this washed out custom shapes entirely and hid the analytic path's edge optics. The
  shaders now take the widget's rect (`uRectOrigin`/`uRectSize`), injected at paint time by a new
  `GlassBackdrop` render object that measures its own on-screen position in device pixels.
- `GlassFilterBuilder` now creates **one** `FragmentShader` for its lifetime and only updates
  uniforms per frame (previously it allocated a new shader every build — jank + GPU-state leak —
  and never disposed them). `GlassContainer` disposes the builder with its state.
- `GlassMaterial.blurSigma` now works on the shader path too: the backdrop is blurred
  (`ImageFilter.compose`) before the optics shader samples it, so glass is frosted on Impeller,
  not only on the fallback. Previously only the fallback path blurred.
- `GlassLight.intensity` is wired into the shader (`uIntensity` scales specular + Fresnel);
  it was previously dead code.

### Changed
- **Breaking (pre-release):** `GlassContainer.flipY` is gone — the GLES backdrop flip is handled
  at shader compile time via `IMPELLER_TARGET_OPENGLES`, so no configuration is needed.
- **Breaking (pre-release):** `GlassMaterial.toShaderFloats` takes `lightIntensity` instead of
  `yFlip`; `GlassFilterBuilder.build` takes a `GlassLight` instead of `lightDir`/`glesYFlip`.
- Rendering capabilities are detected once per `GlassContainer` state instead of on every build,
  and the fallback path's extra blur is a named, documented constant.

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
