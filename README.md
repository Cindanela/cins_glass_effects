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
| Android, iOS (Impeller) | Full shader: refraction, chromatic aberration, specular, Fresnel, tint |
| Windows / macOS / Linux desktop (Impeller) | Full shader |
| Web, or any non‑Impeller backend | Blur + tint fallback (no real refraction) |

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

Each "type" of glass is just a tuned `GlassMaterial`. Two presets ship today:

```dart
GlassMaterials.liquid  // strong refraction, visible fringing, glossy
GlassMaterials.clear   // cleaner, lighter refraction with a crisp rim
```

Or build your own:

```dart
const frosted = GlassMaterial(
  refraction: 4,
  chromaticAberration: 0.5,
  specular: 0.3,
  shininess: 32,
  fresnel: 0.4,
  tint: Color(0x22FFFFFF),
  blurSigma: 8,
  edgeWidth: 14,
);
```

`GlassMaterial` supports `copyWith` and `GlassMaterial.lerp(a, b, t)` for animating between looks.

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

Glass is clipped to a `GlassShape`, so it isn't limited to Material's shapes:

```dart
GlassContainer(shape: const GlassShape.roundedRect(40), child: /* ... */);
```

Phase 1 supports rounded rectangles (any corner radius — set it large for a pill). Arbitrary `Path`
shapes are on the [Roadmap](#roadmap).

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

- Real refraction needs Impeller; web uses the blur + tint fallback.
- Shader **visuals** can't be verified by headless tests (they need Impeller) — check the look on a
  device via the example app. The package's unit/widget tests cover the math, presets, capability
  gating, and fallback path.
- Some Android OpenGL‑ES backends render the sampled backdrop vertically flipped; set
  `GlassContainer(flipY: true)` if you hit that.

## License

See [LICENSE](LICENSE).
