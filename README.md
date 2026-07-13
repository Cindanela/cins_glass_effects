# cins_glass_effects

Turn any Flutter widget or custom shape into convincing **real glass** — not flat translucency, but
physically‑inspired optics: true refraction of the background, chromatic aberration, light‑responsive
specular highlights, Fresnel edges, and tint — rendered with an Impeller fragment shader, with a
graceful blur + tint fallback where custom shaders aren't available.

> **Status: early development (Phase 1).** The rendering engine and one flagship glass (`liquid` /
> `clear`) are implemented and working. The wider catalogue of glass types listed under
> [Roadmap](#roadmap) is not built yet. The API may still change.

## Requirements

- **Flutter 3.44+ / Dart 3.12+**
- The full effect (real backdrop refraction) requires the **Impeller** rendering engine. On backends
  without it (notably **web**), the package automatically falls back to a blur + tint look.

| Platform | What you get |
| --- | --- |
| Android, iOS (Impeller) | Full shader: refraction, chromatic aberration, specular, Fresnel, tint, frost |
| Desktop / web / any backend without `ImageFilter.shader` | Blur + tint fallback (no real refraction) |

On the shader path, **every shape gets full optics**: rounded rects run the analytic shader; any
other silhouette with distance maths (circles, polygons, blobs, boolean cut-outs) is baked into a
signed-distance texture and rendered by the baked-SDF shader. The fallback only remains for
non-Impeller backends and `GlassShape.path` without an `sdfFn`.

The package detects this at runtime via `GlassCapabilities` — you don't have to branch on platform
yourself.

## Installation

Not yet published to pub.dev. Add it from git:

```yaml
dependencies:
  cins_glass_effects:
    git:
      url: https://github.com/Cindanela/cins_glass_effects.git
```

## Quick start

A glass widget refracts whatever is painted **behind** it, so place it over some content (e.g. in a
`Stack`):

```dart
import 'package:flutter/material.dart';
import 'package:cins_glass_effects/cins_glass_effects.dart';

Stack(
  children: [
    // ...your background (an image, gradient, list, etc.)...
    Center(
      child: GlassContainer(
        material: GlassMaterials.liquid,
        shape: const GlassShape.roundedRect(28),
        child: const SizedBox(width: 240, height: 140),
      ),
    ),
  ],
);
```

## Choosing a look

Each "type" of glass is just a tuned `GlassMaterial`. Three presets ship today:

```dart
GlassMaterials.liquid   // strong refraction, visible fringing, glossy
GlassMaterials.clear    // cleaner, lighter refraction with a crisp rim
GlassMaterials.frosted  // deep blur + tactile grain, soft rim
```

Or build your own:

```dart
const bathroomWindow = GlassMaterial(
  refraction: 4,
  chromaticAberration: 0.5,
  specular: 0.3,
  shininess: 32,
  fresnel: 0.4,
  tint: Color(0x22FFFFFF),
  blurSigma: 8,
  edgeWidth: 14,
  grain: 0.5, // frosted-surface noise
);
```

`GlassMaterial` supports `copyWith` and `GlassMaterial.lerp(a, b, t)`. To animate between looks,
use `AnimatedGlassContainer` — an implicitly animated `GlassContainer` (same API plus
`duration`/`curve`) that tweens every optical parameter:

```dart
AnimatedGlassContainer(
  duration: const Duration(milliseconds: 250),
  material: focused ? GlassMaterials.liquid : GlassMaterials.clear,
  child: /* ... */,
);
```

Shapes include `roundedRect`, `circle`, `squircle` (superellipse — iOS-style continuous corners),
`polygon` (absolute coordinates), `normalizedPolygon` (unit-square coordinates that stretch to the
widget), arbitrary `path`, and boolean combinators (`union`/`intersection`/`difference`).

## Lighting (opt‑in, nothing forced)

Specular highlights follow a light direction you choose how to drive. The default costs nothing extra:

- **`ManualLightSource`** *(default)* — you set the angle; zero dependencies.
- **`PointerLightSource`** — the highlight follows the mouse/touch:

  ```dart
  final light = PointerLightSource();
  // ...
  MouseRegion(
    onHover: (e) => light.update(e.localPosition, const Size(240, 140)),
    child: GlassContainer(lightSource: light, child: /* ... */),
  );
  ```

- **`StreamLightSource`** — pipe in any stream of `GlassLight`. This is how you opt into physical
  device tilt **without** this package depending on a sensors plugin:

  ```dart
  // You add sensors_plus yourself and map its events to GlassLight:
  final light = StreamLightSource(
    gyroscopeEvents.map((g) => GlassLight(direction: Offset(g.x, g.y))),
  );
  ```

Remember to `dispose()` a light source you create.

## Custom shapes

A `GlassShape` describes the silhouette as a signed-distance field, and shapes compose, so glass isn't
limited to Material's shapes — or to a single primitive:

```dart
// Built-ins
GlassContainer(shape: const GlassShape.roundedRect(40), child: /* ... */); // pill: large radius
GlassContainer(shape: const GlassShape.circle(), child: /* ... */);

// Any outline
GlassContainer(shape: GlassShape.path((size) => myPath(size)), child: /* ... */);

// Compose: a bar with a hole punched in it
final barWithHole = const GlassShape.roundedRect(24).difference(hole);
```

Use `union` / `intersection` / `difference` to combine shapes; the edge (refraction, Fresnel rim) follows
the composed outline exactly — including the inner rim of a hole. Shapes the GPU shader can't yet render
directly fall back to a shape-accurate CPU path, so the silhouette is always correct (full shader optics
for arbitrary shapes are on the [Roadmap](#roadmap)).

## How it works

A glass widget is a single primitive: a shape clip wrapping a `BackdropFilter` that runs one
parameterized fragment shader (`shaders/glass.frag`). A signed‑distance field derived from the shape
drives the edge‑aware refraction, Fresnel and bevel, so the look is correct on any shape. When custom
shaders aren't supported, the same `GlassContainer` renders a `BackdropFilter` blur plus a painted
tint/rim instead.

## Running the example

The `example/` app is a small gallery for verifying the effect on a real device:

```bash
cd example
flutter run            # an Impeller device/emulator → the full glass
flutter run -d chrome  # web → the blur + tint fallback
```

Move the pointer over the glass card to see the highlight track it, and watch the background warp
through the glass.

## Roadmap

Implemented: the engine + **Liquid** and **Clear** glass.

Planned glass types: Opaque, Frosted / Frosted Glass, Smoked / Tinted, Textured / Reeded,
Frosted‑with‑Grain / Noise, Crystalline / Faceted, Wet Glass / Condensation, Neumorphic Glass,
Beveled Glass, Holographic / Iridescent, Specular / Glossy, Bubble Glass, Stained Glass, Acrylic —
plus arbitrary `Path` shapes, desktop polish, and a refined web fallback.

## Known limitations

- Real refraction needs Impeller with `ImageFilter.shader` support; web and (currently) desktop
  use the blur + tint fallback.
- Shader **visuals** can't be verified by headless tests (they need Impeller) — check the look on a
  device via the example app. The package's unit/widget tests cover the math, presets, capability
  gating, and fallback path.
- Android OpenGL‑ES backdrop orientation is handled automatically in the shader
  (compile-time `IMPELLER_TARGET_OPENGLES` flip) — no configuration needed.

## License

See [LICENSE](LICENSE).
