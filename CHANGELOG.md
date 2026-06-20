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
- `GlassShape.roundedRect` (+ `GlassClipper`) and `ShapeSdf.roundedRect` (the signed-distance math the
  shader mirrors).
- Pluggable, opt-in lighting: `ManualLightSource` (default), `PointerLightSource`, and
  `StreamLightSource` — physical-tilt support is opt-in via a stream, so `sensors_plus` is never a
  dependency.
- Runtime capability detection (`GlassCapabilities`, `resolveGlassRenderPath`) and a `GlassQuality` knob.
- `example/` gallery app for on-device visual verification.

### Notes
- Zero third-party runtime dependencies.
- The flagship `liquid` / `clear` glass is implemented; the wider catalogue of glass types is planned
  (see the README roadmap).
