# Glass Engine — Phase 0 + Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `cins_glass_effects` package skeleton and deliver one flagship "Liquid/Clear" glass that truly refracts the real backdrop (refraction + chromatic aberration + specular + Fresnel + tint), with a graceful blur+tint fallback where custom shaders aren't supported.

**Architecture:** One rendering primitive — a `ShapeBorder`/rounded-rect clip wrapping a `BackdropFilter` that runs a single parameterized fragment shader (`shaders/glass.frag`) via `ui.ImageFilter.shader`. Optical look is data (`GlassMaterial`); geometry is a `GlassShape`; light is a pluggable `ValueListenable<GlassLight>`. A pure-Dart `ShapeSdf` is the executable spec of the SDF math the GLSL copies verbatim.

**Tech Stack:** Flutter 3.44 / Dart 3.12, `dart:ui` (`FragmentProgram`, `ImageFilter.shader`, `BackdropFilter`), GLSL fragment shaders, `flutter_test`.

## Global Constraints

- Dart SDK `^3.12.0`, Flutter `3.44` (floor `>=1.17.0` in pubspec).
- **Zero runtime dependencies** in the package. `sensors_plus` must never be a dependency (gyro is opt-in by the app via a `Stream<GlassLight>`).
- Public API is re-exported ONLY from `lib/cins_glass_effects.dart`; implementation lives in `lib/src/…`.
- `ui.ImageFilter.shader` is **Impeller-only**; gate every use behind `GlassCapabilities` and fall back to `ImageFilter.blur`.
- Shader visuals CANNOT be golden-tested headlessly (no Impeller in `flutter test`). Headless tests cover pure logic only; shader fidelity is verified on-device via `example/`.
- Use Flutter 3.44 `Color` channel accessors `.r .g .b .a` (doubles 0..1) — not deprecated `.red/.green/.blue`.
- Keep `flutter analyze` clean. Commit after each task (skip if the user isn't using git).

## File Structure

```
lib/cins_glass_effects.dart                  # barrel (re-exports)
lib/src/optics/glass_quality.dart            # GlassQuality enum
lib/src/optics/glass_capabilities.dart       # capability detection (injectable)
lib/src/optics/glass_render_path.dart        # resolveGlassRenderPath()
lib/src/geometry/shape_sdf.dart              # ShapeSdf.roundedRect (tested twin of GLSL)
lib/src/geometry/glass_shape.dart            # GlassShape (rounded-rect) + clipper
lib/src/materials/glass_material.dart        # GlassMaterial + copyWith/lerp/toShaderFloats
lib/src/materials/glass_presets.dart         # GlassMaterial.liquid (+ clear)
lib/src/light/glass_light.dart               # GlassLight + sources (manual/stream/pointer)
lib/src/optics/glass_filter_builder.dart     # builds ImageFilter.shader from inputs
lib/src/widgets/glass_fallback.dart          # blur+tint fallback overlay painter
lib/src/widgets/glass_container.dart         # GlassContainer widget (+ raw shape entry)
shaders/glass.frag                           # the optics shader
example/lib/main.dart                        # gallery / visual harness
test/…                                       # mirrors lib/src
```

---

### Task 1: Package scaffold, pubspec shader wiring, barrel

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/cins_glass_effects.dart`
- Create: `test/barrel_test.dart`

**Interfaces:**
- Produces: package compiles; `shaders/glass.frag` registered as an asset; barrel exists for later re-exports.

- [ ] **Step 1: Add the shader section to `pubspec.yaml`** (replace the empty `flutter:` block)

```yaml
flutter:
  shaders:
    - shaders/glass.frag
```

- [ ] **Step 2: Create a placeholder shader so the asset resolves** at `shaders/glass.frag`

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;
layout(location = 0) uniform vec2 uSize;
uniform sampler2D uTexture;
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  fragColor = texture(uTexture, uv);
}
```

- [ ] **Step 3: Set the barrel header** in `lib/cins_glass_effects.dart`

```dart
/// cins_glass_effects — turn any widget or shape into real glass.
///
/// Public API is re-exported here; implementations live in `lib/src/`.
library;
```

- [ ] **Step 4: Write a smoke test** at `test/barrel_test.dart`

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package imports without error', () {
    expect(true, isTrue);
  });
}
```

- [ ] **Step 5: Run** `flutter pub get && flutter test test/barrel_test.dart` — Expected: PASS.
- [ ] **Step 6: Commit** — `git add -A && git commit -m "chore: scaffold package + shader asset wiring"`

---

### Task 2: GlassQuality enum

**Files:**
- Create: `lib/src/optics/glass_quality.dart`
- Test: `test/optics/glass_quality_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Produces: `enum GlassQuality { low, medium, high }` with `int get refractionSamples`, `int get blurPasses`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quality exposes sample/blur budgets ascending', () {
    expect(GlassQuality.low.refractionSamples, lessThan(GlassQuality.high.refractionSamples));
    expect(GlassQuality.high.blurPasses, 3);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/optics/glass_quality_test.dart` — Expected: FAIL (GlassQuality undefined).
- [ ] **Step 3: Implement** `lib/src/optics/glass_quality.dart`

```dart
/// How much GPU work the glass effect is allowed to spend.
enum GlassQuality {
  low(refractionSamples: 1, blurPasses: 1),
  medium(refractionSamples: 3, blurPasses: 2),
  high(refractionSamples: 5, blurPasses: 3);

  const GlassQuality({required this.refractionSamples, required this.blurPasses});

  final int refractionSamples;
  final int blurPasses;
}
```

- [ ] **Step 4: Export** — add to `lib/cins_glass_effects.dart`: `export 'src/optics/glass_quality.dart';`
- [ ] **Step 5: Run** the test — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: GlassQuality budget enum"`

---

### Task 3: GlassCapabilities (injectable detection)

**Files:**
- Create: `lib/src/optics/glass_capabilities.dart`
- Test: `test/optics/glass_capabilities_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Produces: `class GlassCapabilities { const GlassCapabilities({required bool shaderFiltersSupported}); factory GlassCapabilities.detect(); final bool shaderFiltersSupported; }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit capabilities are honoured', () {
    expect(const GlassCapabilities(shaderFiltersSupported: false).shaderFiltersSupported, isFalse);
    expect(const GlassCapabilities(shaderFiltersSupported: true).shaderFiltersSupported, isTrue);
  });

  test('detect() returns a value without throwing', () {
    expect(GlassCapabilities.detect().shaderFiltersSupported, isA<bool>());
  });
}
```

- [ ] **Step 2: Run** the test — Expected: FAIL (undefined).
- [ ] **Step 3: Implement** `lib/src/optics/glass_capabilities.dart`

```dart
import 'dart:ui' as ui;

/// Runtime rendering capabilities relevant to glass effects.
class GlassCapabilities {
  const GlassCapabilities({required this.shaderFiltersSupported});

  /// Probes the real engine. `ImageFilter.shader` requires Impeller.
  factory GlassCapabilities.detect() =>
      GlassCapabilities(shaderFiltersSupported: ui.ImageFilter.isShaderFilterSupported);

  /// Whether `ui.ImageFilter.shader` can be used on this backend.
  final bool shaderFiltersSupported;
}
```

- [ ] **Step 4: Export** — add `export 'src/optics/glass_capabilities.dart';`
- [ ] **Step 5: Run** the test — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: GlassCapabilities detection"`

---

### Task 4: resolveGlassRenderPath()

**Files:**
- Create: `lib/src/optics/glass_render_path.dart`
- Test: `test/optics/glass_render_path_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Consumes: `GlassCapabilities` (Task 3).
- Produces: `enum GlassRenderPath { shader, fallback }` and `GlassRenderPath resolveGlassRenderPath({required GlassCapabilities capabilities, bool forceFallback = false})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses shader when supported, fallback otherwise', () {
    expect(
      resolveGlassRenderPath(capabilities: const GlassCapabilities(shaderFiltersSupported: true)),
      GlassRenderPath.shader,
    );
    expect(
      resolveGlassRenderPath(capabilities: const GlassCapabilities(shaderFiltersSupported: false)),
      GlassRenderPath.fallback,
    );
  });

  test('forceFallback overrides support', () {
    expect(
      resolveGlassRenderPath(
        capabilities: const GlassCapabilities(shaderFiltersSupported: true),
        forceFallback: true,
      ),
      GlassRenderPath.fallback,
    );
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `lib/src/optics/glass_render_path.dart`

```dart
import 'glass_capabilities.dart';

/// Which rendering strategy a glass widget should use.
enum GlassRenderPath { shader, fallback }

/// Picks the shader path only when custom shader filters are available.
GlassRenderPath resolveGlassRenderPath({
  required GlassCapabilities capabilities,
  bool forceFallback = false,
}) {
  if (forceFallback || !capabilities.shaderFiltersSupported) {
    return GlassRenderPath.fallback;
  }
  return GlassRenderPath.shader;
}
```

- [ ] **Step 4: Export** — add `export 'src/optics/glass_render_path.dart';`
- [ ] **Step 5: Run** — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: glass render-path resolver"`

---

### Task 5: ShapeSdf.roundedRect (tested twin of the GLSL SDF)

**Files:**
- Create: `lib/src/geometry/shape_sdf.dart`
- Test: `test/geometry/shape_sdf_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Produces: `double ShapeSdf.roundedRect(Offset p, Size halfExtent, double radius)` — signed distance (negative inside) from a point relative to the rect's center. This exact formula is copied into `glass.frag`.

- [ ] **Step 1: Write the failing test** (values verified by hand for halfExtent 50×50, radius 10)

```dart
import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const half = Size(50, 50);
  const r = 10.0;

  test('center is -50 (50px inside the nearest edge)', () {
    expect(ShapeSdf.roundedRect(Offset.zero, half, r), closeTo(-50, 1e-6));
  });

  test('on the straight edge is ~0', () {
    expect(ShapeSdf.roundedRect(const Offset(50, 0), half, r), closeTo(0, 1e-6));
  });

  test('10px past the edge is +10', () {
    expect(ShapeSdf.roundedRect(const Offset(60, 0), half, r), closeTo(10, 1e-6));
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `lib/src/geometry/shape_sdf.dart`

```dart
import 'dart:math' as math;
import 'dart:ui';

/// Pure-Dart signed-distance functions. This is the executable specification
/// of the SDF math used inside `shaders/glass.frag` (which cannot be unit
/// tested because it requires Impeller). Keep the two in lockstep.
class ShapeSdf {
  const ShapeSdf._();

  /// Signed distance from [p] (relative to the rect centre) to a rounded
  /// rectangle of half-extent [halfExtent] and uniform corner [radius].
  /// Negative inside, zero on the boundary, positive outside.
  static double roundedRect(Offset p, Size halfExtent, double radius) {
    final qx = p.dx.abs() - halfExtent.width + radius;
    final qy = p.dy.abs() - halfExtent.height + radius;
    final outside = math.sqrt(math.pow(math.max(qx, 0.0), 2) + math.pow(math.max(qy, 0.0), 2));
    final inside = math.min(math.max(qx, qy), 0.0);
    return outside + inside - radius;
  }
}
```

- [ ] **Step 4: Export** — add `export 'src/geometry/shape_sdf.dart';`
- [ ] **Step 5: Run** — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: rounded-rect SDF (Dart twin of shader)"`

---

### Task 6: GlassShape + clipper

**Files:**
- Create: `lib/src/geometry/glass_shape.dart`
- Test: `test/geometry/glass_shape_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Produces: `class GlassShape { const GlassShape.roundedRect(double cornerRadius); final double cornerRadius; Path clipPath(Size size); }` and `class GlassClipper extends CustomClipper<Path>`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clip path covers the size and contains the centre', () {
    const shape = GlassShape.roundedRect(16);
    final path = shape.clipPath(const Size(200, 100));
    expect(path.getBounds().width, closeTo(200, 1e-3));
    expect(path.contains(const Offset(100, 50)), isTrue);
    expect(path.contains(const Offset(-5, -5)), isFalse);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `lib/src/geometry/glass_shape.dart`

```dart
import 'package:flutter/widgets.dart';

/// The geometry of a glass surface. Phase 1 supports a uniform-radius
/// rounded rectangle; arbitrary `Path` shapes arrive in a later phase.
@immutable
class GlassShape {
  const GlassShape.roundedRect(this.cornerRadius);

  final double cornerRadius;

  Path clipPath(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cornerRadius)));

  @override
  bool operator ==(Object other) =>
      other is GlassShape && other.cornerRadius == cornerRadius;

  @override
  int get hashCode => cornerRadius.hashCode;
}

/// Clips a child to a [GlassShape].
class GlassClipper extends CustomClipper<Path> {
  const GlassClipper(this.shape);

  final GlassShape shape;

  @override
  Path getClip(Size size) => shape.clipPath(size);

  @override
  bool shouldReclip(GlassClipper oldClipper) => oldClipper.shape != shape;
}
```

- [ ] **Step 4: Export** — add `export 'src/geometry/glass_shape.dart';`
- [ ] **Step 5: Run** — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: GlassShape + clipper"`

---

### Task 7: GlassMaterial (value object + uniform packing)

**Files:**
- Create: `lib/src/materials/glass_material.dart`
- Test: `test/materials/glass_material_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Produces: immutable `GlassMaterial` with optical fields, `copyWith`, `lerp`, value equality, and
  `Float32List toShaderFloats({required Offset lightDir, required double cornerRadius, required double yFlip})`
  returning floats for shader indices 2..15 (uSize occupies 0,1).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const m = GlassMaterial(
    refraction: 12,
    chromaticAberration: 3,
    specular: 0.5,
    shininess: 32,
    fresnel: 0.6,
    tint: Color(0x80112233),
    blurSigma: 2,
    edgeWidth: 18,
  );

  test('value equality + copyWith', () {
    expect(m, equals(m.copyWith()));
    expect(m.copyWith(refraction: 99).refraction, 99);
    expect(m == m.copyWith(refraction: 99), isFalse);
  });

  test('lerp interpolates fields', () {
    final a = const GlassMaterial(refraction: 0);
    final b = const GlassMaterial(refraction: 10);
    expect(GlassMaterial.lerp(a, b, 0.5).refraction, closeTo(5, 1e-6));
  });

  test('toShaderFloats packs uniforms in declared order', () {
    final f = m.toShaderFloats(lightDir: const Offset(0.1, 0.2), cornerRadius: 24, yFlip: 1);
    // [lx, ly, refraction, chroma, specular, shininess, fresnel, r,g,b,a, corner, edge, yflip]
    expect(f.length, 15);
    expect(f[0], closeTo(0.1, 1e-6));   // lightDir.x  -> shader idx 2
    expect(f[1], closeTo(0.2, 1e-6));   // lightDir.y  -> idx 3
    expect(f[2], closeTo(12, 1e-6));    // refraction  -> idx 4
    expect(f[10], closeTo(0x80 / 255, 1e-6)); // tint.a -> idx 12
    expect(f[11], closeTo(24, 1e-6));   // cornerRadius-> idx 13
    expect(f[13], closeTo(1, 1e-6));    // yFlip       -> idx 15
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `lib/src/materials/glass_material.dart`

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The optical description of a sheet of glass. Purely data — the same
/// material renders through either the shader path or the fallback path.
@immutable
class GlassMaterial {
  const GlassMaterial({
    this.refraction = 0.0,
    this.chromaticAberration = 0.0,
    this.specular = 0.0,
    this.shininess = 32.0,
    this.fresnel = 0.0,
    this.tint = const Color(0x00FFFFFF),
    this.blurSigma = 0.0,
    this.edgeWidth = 12.0,
  });

  /// Max backdrop displacement near edges, in logical px.
  final double refraction;

  /// Per-channel offset for colour fringing, in logical px.
  final double chromaticAberration;

  /// Specular highlight strength, 0..1.
  final double specular;

  /// Specular exponent (higher = tighter highlight).
  final double shininess;

  /// Fresnel rim brightness, 0..1.
  final double fresnel;

  /// Glass colour wash (alpha = strength).
  final Color tint;

  /// Backdrop blur sigma (used by the fallback path; subtle in shader path).
  final double blurSigma;

  /// Width (px) of the reactive edge band that drives Fresnel/refraction.
  final double edgeWidth;

  GlassMaterial copyWith({
    double? refraction,
    double? chromaticAberration,
    double? specular,
    double? shininess,
    double? fresnel,
    Color? tint,
    double? blurSigma,
    double? edgeWidth,
  }) {
    return GlassMaterial(
      refraction: refraction ?? this.refraction,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      specular: specular ?? this.specular,
      shininess: shininess ?? this.shininess,
      fresnel: fresnel ?? this.fresnel,
      tint: tint ?? this.tint,
      blurSigma: blurSigma ?? this.blurSigma,
      edgeWidth: edgeWidth ?? this.edgeWidth,
    );
  }

  static GlassMaterial lerp(GlassMaterial a, GlassMaterial b, double t) {
    return GlassMaterial(
      refraction: lerpDouble(a.refraction, b.refraction, t)!,
      chromaticAberration: lerpDouble(a.chromaticAberration, b.chromaticAberration, t)!,
      specular: lerpDouble(a.specular, b.specular, t)!,
      shininess: lerpDouble(a.shininess, b.shininess, t)!,
      fresnel: lerpDouble(a.fresnel, b.fresnel, t)!,
      tint: Color.lerp(a.tint, b.tint, t)!,
      blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t)!,
      edgeWidth: lerpDouble(a.edgeWidth, b.edgeWidth, t)!,
    );
  }

  /// Floats for shader uniform indices 2..15. Index 0,1 are `uSize`, which the
  /// engine sets automatically for `ImageFilter.shader`. Order MUST match the
  /// uniform declaration order in `shaders/glass.frag`.
  Float32List toShaderFloats({
    required Offset lightDir,
    required double cornerRadius,
    required double yFlip,
  }) {
    return Float32List.fromList(<double>[
      lightDir.dx, lightDir.dy,
      refraction,
      chromaticAberration,
      specular,
      shininess,
      fresnel,
      tint.r, tint.g, tint.b, tint.a,
      cornerRadius,
      edgeWidth,
      yFlip,
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is GlassMaterial &&
      other.refraction == refraction &&
      other.chromaticAberration == chromaticAberration &&
      other.specular == specular &&
      other.shininess == shininess &&
      other.fresnel == fresnel &&
      other.tint == tint &&
      other.blurSigma == blurSigma &&
      other.edgeWidth == edgeWidth;

  @override
  int get hashCode => Object.hash(
        refraction, chromaticAberration, specular, shininess,
        fresnel, tint, blurSigma, edgeWidth,
      );
}
```

- [ ] **Step 4: Export** — add `export 'src/materials/glass_material.dart';`
- [ ] **Step 5: Run** — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: GlassMaterial value object + uniform packing"`

---

### Task 8: Presets (liquid, clear)

**Files:**
- Create: `lib/src/materials/glass_presets.dart`
- Test: `test/materials/glass_presets_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Consumes: `GlassMaterial` (Task 7).
- Produces: `extension GlassPresets on GlassMaterial` exposing `static const GlassMaterial liquid` and `clear`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('liquid preset is refractive and specular', () {
    expect(GlassMaterials.liquid.refraction, greaterThan(0));
    expect(GlassMaterials.liquid.specular, greaterThan(0));
    expect(GlassMaterials.liquid.chromaticAberration, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `lib/src/materials/glass_presets.dart`

```dart
import 'dart:ui';

import 'glass_material.dart';

/// Named glass recipes. Each "type" of glass is just a tuned [GlassMaterial].
abstract final class GlassMaterials {
  /// Apple-style "liquid" glass: strong refraction, visible fringing, glossy.
  static const GlassMaterial liquid = GlassMaterial(
    refraction: 14,
    chromaticAberration: 3,
    specular: 0.7,
    shininess: 48,
    fresnel: 0.6,
    tint: Color(0x14FFFFFF),
    blurSigma: 2,
    edgeWidth: 18,
  );

  /// Clean, nearly-clear glass with light refraction and a crisp rim.
  static const GlassMaterial clear = GlassMaterial(
    refraction: 8,
    chromaticAberration: 1.5,
    specular: 0.5,
    shininess: 64,
    fresnel: 0.5,
    tint: Color(0x0AFFFFFF),
    blurSigma: 0.5,
    edgeWidth: 14,
  );
}
```

- [ ] **Step 4: Export** — add `export 'src/materials/glass_presets.dart';`
- [ ] **Step 5: Run** — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: liquid + clear glass presets"`

---

### Task 9: GlassLight + light sources

**Files:**
- Create: `lib/src/light/glass_light.dart`
- Test: `test/light/glass_light_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Produces: `class GlassLight { const GlassLight({required Offset direction, double intensity}); static const GlassLight topLeft; }`,
  `typedef GlassLightSource = ValueListenable<GlassLight>`,
  `class ManualLightSource extends ValueNotifier<GlassLight>`,
  `class StreamLightSource extends ValueNotifier<GlassLight>` (opt-in gyro adaptor),
  `class PointerLightSource extends ValueNotifier<GlassLight>` with `void update(Offset localPosition, Size size)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:async';
import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual source notifies on change', () {
    final src = ManualLightSource(const GlassLight(direction: Offset(0, -1)));
    var notified = 0;
    src.addListener(() => notified++);
    src.value = const GlassLight(direction: Offset(1, 0));
    expect(notified, 1);
    expect(src.value.direction, const Offset(1, 0));
  });

  test('stream source tracks the latest event', () async {
    final ctrl = StreamController<GlassLight>();
    final src = StreamLightSource(ctrl.stream);
    ctrl.add(const GlassLight(direction: Offset(0.3, 0.4)));
    await Future<void>.delayed(Duration.zero);
    expect(src.value.direction, const Offset(0.3, 0.4));
    await ctrl.close();
    src.dispose();
  });

  test('pointer source maps centre to zero direction', () {
    final src = PointerLightSource();
    src.update(const Offset(50, 50), const Size(100, 100));
    expect(src.value.direction.dx, closeTo(0, 1e-6));
    expect(src.value.direction.dy, closeTo(0, 1e-6));
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** `lib/src/light/glass_light.dart`

```dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A light striking the glass: a 2D incoming direction and an intensity.
@immutable
class GlassLight {
  const GlassLight({required this.direction, this.intensity = 1.0});

  final Offset direction;
  final double intensity;

  static const GlassLight topLeft = GlassLight(direction: Offset(-0.5, -0.7));

  @override
  bool operator ==(Object other) =>
      other is GlassLight && other.direction == direction && other.intensity == intensity;

  @override
  int get hashCode => Object.hash(direction, intensity);
}

/// The contract glass widgets consume. Implementations are [Listenable].
typedef GlassLightSource = ValueListenable<GlassLight>;

/// App-controlled light (default, zero dependencies).
class ManualLightSource extends ValueNotifier<GlassLight> {
  ManualLightSource([GlassLight light = GlassLight.topLeft]) : super(light);
}

/// Opt-in adaptor: pipe any stream (e.g. `sensors_plus` gyroscope, mapped to a
/// [GlassLight]) into the glass without the package depending on sensors.
class StreamLightSource extends ValueNotifier<GlassLight> {
  StreamLightSource(Stream<GlassLight> stream, {GlassLight initial = GlassLight.topLeft})
      : super(initial) {
    _sub = stream.listen((light) => value = light);
  }

  late final StreamSubscription<GlassLight> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Light that follows a pointer. Centre of the surface = head-on (zero) light.
class PointerLightSource extends ValueNotifier<GlassLight> {
  PointerLightSource() : super(GlassLight.topLeft);

  void update(Offset localPosition, Size size) {
    final dx = (localPosition.dx / size.width) * 2 - 1;
    final dy = (localPosition.dy / size.height) * 2 - 1;
    value = GlassLight(direction: Offset(dx, dy));
  }
}
```

- [ ] **Step 4: Export** — add `export 'src/light/glass_light.dart';`
- [ ] **Step 5: Run** — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: GlassLight + manual/stream/pointer sources"`

---

### Task 10: glass.frag — the optics shader

**Files:**
- Modify: `shaders/glass.frag` (replace the Task 1 placeholder)

**Interfaces:**
- Consumes (uniform layout, MUST match `GlassMaterial.toShaderFloats`):
  `uSize`(0,1, engine-set), `uLightDir`(2,3), `uRefraction`(4), `uChromatic`(5), `uSpecular`(6),
  `uShininess`(7), `uFresnel`(8), `uTint`(9-12), `uCornerRadius`(13), `uEdgeWidth`(14), `uYFlip`(15),
  `uTexture`(sampler 0, engine-set backdrop).
- Produces: a filtered backdrop with refraction + chromatic aberration + Fresnel + specular + tint, masked to the rounded-rect shape.

- [ ] **Step 1: Replace `shaders/glass.frag` with the full shader**

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

layout(location = 0) uniform vec2  uSize;         // floats 0,1 (engine: input size)
layout(location = 1) uniform vec2  uLightDir;     // 2,3
layout(location = 2) uniform float uRefraction;   // 4
layout(location = 3) uniform float uChromatic;    // 5
layout(location = 4) uniform float uSpecular;     // 6
layout(location = 5) uniform float uShininess;    // 7
layout(location = 6) uniform float uFresnel;      // 8
layout(location = 7) uniform vec4  uTint;         // 9,10,11,12
layout(location = 8) uniform float uCornerRadius; // 13
layout(location = 9) uniform float uEdgeWidth;    // 14
layout(location = 10) uniform float uYFlip;       // 15

uniform sampler2D uTexture;                        // sampler 0: backdrop

out vec4 fragColor;

// MUST stay identical to ShapeSdf.roundedRect (Dart twin).
float sdRoundedBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;
  if (uYFlip > 0.5) { uv.y = 1.0 - uv.y; }

  vec2 halfSize = uSize * 0.5;
  vec2 p = fragCoord - halfSize;
  vec2 b = halfSize - vec2(1.0);

  float d = sdRoundedBox(p, b, uCornerRadius);      // negative inside

  // Surface normal from the SDF gradient (finite differences).
  const float e = 1.0;
  float gx = sdRoundedBox(p + vec2(e, 0.0), b, uCornerRadius) -
             sdRoundedBox(p - vec2(e, 0.0), b, uCornerRadius);
  float gy = sdRoundedBox(p + vec2(0.0, e), b, uCornerRadius) -
             sdRoundedBox(p - vec2(0.0, e), b, uCornerRadius);
  vec2 grad = normalize(vec2(gx, gy) + vec2(1e-5));

  // Edge band: 1 at the rim, 0 deep inside.
  float depth = -d;                                  // px inside (positive)
  float edge = 1.0 - smoothstep(0.0, uEdgeWidth, depth);
  edge = clamp(edge, 0.0, 1.0);

  // Refraction + chromatic aberration: sample the backdrop, displaced along
  // the inward normal, more strongly near the edges.
  vec2 refr = grad * (uRefraction * edge) / uSize;
  vec2 ca   = grad * (uChromatic  * edge) / uSize;
  float rC = texture(uTexture, uv + refr + ca).r;
  float gC = texture(uTexture, uv + refr).g;
  float bC = texture(uTexture, uv + refr - ca).b;
  vec3 color = vec3(rC, gC, bC);

  // Glass tint.
  color = mix(color, uTint.rgb, uTint.a);

  // Fresnel rim brightening.
  color += vec3(pow(edge, 2.0) * uFresnel);

  // Specular highlight off the beveled edge.
  vec3 n = normalize(vec3(grad * edge, 1.0));
  vec3 l = normalize(vec3(uLightDir, 1.0));
  float spec = pow(max(dot(n, l), 0.0), max(uShininess, 1.0)) * uSpecular;
  color += vec3(spec);

  // Anti-aliased mask to the rounded-rect shape.
  float mask = 1.0 - smoothstep(-1.0, 1.0, d);
  fragColor = vec4(color, 1.0) * mask;
}
```

- [ ] **Step 2: Verify it compiles** — Run: `flutter analyze` and build the example later (Task 13). A malformed shader fails at asset bundling. Expected: no analyzer errors (GLSL isn't analyzed, but the asset must exist).
- [ ] **Step 3: Commit** — `git commit -am "feat: glass.frag optics shader (refraction/chroma/specular/fresnel)"`

> Note: there is no headless unit test here — `ImageFilter.shader` requires Impeller. Visual correctness is verified on-device in Task 13.

---

### Task 11: GlassFilterBuilder

**Files:**
- Create: `lib/src/optics/glass_filter_builder.dart`
- Test: `test/optics/glass_filter_builder_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export)

**Interfaces:**
- Consumes: `GlassMaterial.toShaderFloats` (Task 7).
- Produces: `class GlassFilterBuilder { static Future<GlassFilterBuilder> load(); ui.ImageFilter build({required GlassMaterial material, required Offset lightDir, required double cornerRadius, required bool glesYFlip}); }` plus `const glassShaderAsset = 'packages/cins_glass_effects/shaders/glass.frag'`.

- [ ] **Step 1: Write the failing test** (the asset constant is the only headlessly-testable surface)

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shader asset path is package-qualified', () {
    expect(glassShaderAsset, 'packages/cins_glass_effects/shaders/glass.frag');
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (undefined).
- [ ] **Step 3: Implement** `lib/src/optics/glass_filter_builder.dart`

```dart
import 'dart:ui' as ui;

import '../materials/glass_material.dart';

/// Asset key for the optics shader. Package-qualified so consuming apps resolve
/// it correctly.
const String glassShaderAsset = 'packages/cins_glass_effects/shaders/glass.frag';

/// Builds an `ImageFilter.shader` for the glass optics shader. Load once
/// (async), then [build] cheaply per frame as light/material change.
class GlassFilterBuilder {
  GlassFilterBuilder(this._program);

  final ui.FragmentProgram _program;

  static Future<GlassFilterBuilder> load() async =>
      GlassFilterBuilder(await ui.FragmentProgram.fromAsset(glassShaderAsset));

  ui.ImageFilter build({
    required GlassMaterial material,
    required ui.Offset lightDir,
    required double cornerRadius,
    required bool glesYFlip,
  }) {
    final shader = _program.fragmentShader();
    final floats = material.toShaderFloats(
      lightDir: lightDir,
      cornerRadius: cornerRadius,
      yFlip: glesYFlip ? 1.0 : 0.0,
    );
    // Indices 0,1 are uSize (engine-set); our uniforms start at index 2.
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(i + 2, floats[i]);
    }
    return ui.ImageFilter.shader(shader);
  }
}
```

- [ ] **Step 4: Export** — add `export 'src/optics/glass_filter_builder.dart';`
- [ ] **Step 5: Run** — Expected: PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat: GlassFilterBuilder (uniform upload)"`

---

### Task 12: GlassContainer widget + fallback

**Files:**
- Create: `lib/src/widgets/glass_fallback.dart`
- Create: `lib/src/widgets/glass_container.dart`
- Test: `test/widgets/glass_container_test.dart`
- Modify: `lib/cins_glass_effects.dart` (export both)

**Interfaces:**
- Consumes: `GlassShape`, `GlassClipper` (Task 6), `GlassMaterial` (Task 7), `GlassLightSource`/`ManualLightSource` (Task 9), `GlassCapabilities` (Task 3), `resolveGlassRenderPath` (Task 4), `GlassFilterBuilder` (Task 11).
- Produces: `class GlassContainer extends StatefulWidget` with
  `GlassContainer({Key?, required Widget child, GlassMaterial material, GlassShape shape, GlassLightSource? lightSource, GlassCapabilities? capabilities, bool flipY})`.

- [ ] **Step 1: Write the failing widget test** (forces the fallback path so it runs without Impeller)

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('falls back to ClipPath + BackdropFilter without shader support',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const ColoredBox(color: Colors.orange),
            GlassContainer(
              capabilities: const GlassCapabilities(shaderFiltersSupported: false),
              material: GlassMaterials.liquid,
              shape: const GlassShape.roundedRect(20),
              child: const SizedBox(width: 120, height: 80),
            ),
          ],
        ),
      ),
    );

    expect(find.byType(ClipPath), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run** — Expected: FAIL (GlassContainer undefined).
- [ ] **Step 3: Implement the fallback painter** `lib/src/widgets/glass_fallback.dart`

```dart
import 'package:flutter/widgets.dart';

import '../materials/glass_material.dart';

/// Paints a believable glass surface when custom shaders aren't available
/// (e.g. web): a tint wash plus a Fresnel-style rim highlight. Pairs with a
/// `BackdropFilter(ImageFilter.blur)` behind it.
class GlassFallbackOverlay extends CustomPainter {
  GlassFallbackOverlay({required this.material, required this.cornerRadius});

  final GlassMaterial material;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cornerRadius));
    canvas.drawRRect(rrect, Paint()..color = material.tint);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * material.fresnel);
    canvas.drawRRect(rrect.deflate(0.75), rim);
  }

  @override
  bool shouldRepaint(GlassFallbackOverlay old) =>
      old.material != material || old.cornerRadius != cornerRadius;
}
```

- [ ] **Step 4: Implement the widget** `lib/src/widgets/glass_container.dart`

```dart
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../geometry/glass_shape.dart';
import '../light/glass_light.dart';
import '../materials/glass_material.dart';
import '../materials/glass_presets.dart';
import '../optics/glass_capabilities.dart';
import '../optics/glass_filter_builder.dart';
import '../optics/glass_render_path.dart';
import 'glass_fallback.dart';

/// Turns [child] into glass. Uses the shader path on Impeller and a blur+tint
/// fallback elsewhere.
class GlassContainer extends StatefulWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.material = GlassMaterials.liquid,
    this.shape = const GlassShape.roundedRect(28),
    this.lightSource,
    this.capabilities,
    this.flipY = false,
  });

  final Widget child;
  final GlassMaterial material;
  final GlassShape shape;
  final GlassLightSource? lightSource;
  final GlassCapabilities? capabilities;

  /// Set true if the backdrop renders vertically flipped (some Android-GLES).
  final bool flipY;

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  GlassFilterBuilder? _builder;
  late GlassLightSource _light;
  ManualLightSource? _ownedLight;

  @override
  void initState() {
    super.initState();
    _light = widget.lightSource ?? (_ownedLight = ManualLightSource());
    _maybeLoadShader();
  }

  GlassCapabilities get _caps => widget.capabilities ?? GlassCapabilities.detect();

  void _maybeLoadShader() {
    if (resolveGlassRenderPath(capabilities: _caps) == GlassRenderPath.shader) {
      GlassFilterBuilder.load().then((b) {
        if (mounted) setState(() => _builder = b);
      });
    }
  }

  @override
  void dispose() {
    _ownedLight?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clipper = GlassClipper(widget.shape);
    final usesShader =
        resolveGlassRenderPath(capabilities: _caps) == GlassRenderPath.shader && _builder != null;

    if (!usesShader) {
      return ClipPath(
        clipper: clipper,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: widget.material.blurSigma + 6,
            sigmaY: widget.material.blurSigma + 6,
          ),
          child: CustomPaint(
            foregroundPainter: GlassFallbackOverlay(
              material: widget.material,
              cornerRadius: widget.shape.cornerRadius,
            ),
            child: widget.child,
          ),
        ),
      );
    }

    return ValueListenableBuilder<GlassLight>(
      valueListenable: _light,
      builder: (context, light, _) {
        final filter = _builder!.build(
          material: widget.material,
          lightDir: light.direction,
          cornerRadius: widget.shape.cornerRadius,
          glesYFlip: widget.flipY,
        );
        return ClipPath(
          clipper: clipper,
          child: BackdropFilter(filter: filter, child: widget.child),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Export** — add to barrel:
  `export 'src/widgets/glass_container.dart';` and `export 'src/widgets/glass_fallback.dart';`
- [ ] **Step 6: Run** `flutter test test/widgets/glass_container_test.dart` — Expected: PASS.
- [ ] **Step 7: Run** `flutter analyze` — Expected: no issues.
- [ ] **Step 8: Commit** — `git commit -am "feat: GlassContainer widget + blur/tint fallback"`

---

### Task 13: Example gallery app (visual verification harness)

**Files:**
- Create: `example/pubspec.yaml`
- Create: `example/lib/main.dart`

**Interfaces:**
- Consumes: `GlassContainer`, `GlassMaterials`, `GlassShape`, `PointerLightSource` (public API).
- Produces: a runnable app placing the flagship glass over a colourful backdrop, with pointer-driven light — the surface used to eyeball fidelity and capture screenshots.

- [ ] **Step 1: Create `example/pubspec.yaml`**

```yaml
name: cins_glass_effects_example
description: Visual gallery for cins_glass_effects.
publish_to: none
version: 0.0.1

environment:
  sdk: ^3.12.0
  flutter: ">=1.17.0"

dependencies:
  flutter:
    sdk: flutter
  cins_glass_effects:
    path: ../

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Create `example/lib/main.dart`**

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

void main() => runApp(const GlassGalleryApp());

class GlassGalleryApp extends StatelessWidget {
  const GlassGalleryApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(debugShowCheckedModeBanner: false, home: GlassDemoPage());
}

class GlassDemoPage extends StatefulWidget {
  const GlassDemoPage({super.key});

  @override
  State<GlassDemoPage> createState() => _GlassDemoPageState();
}

class _GlassDemoPageState extends State<GlassDemoPage> {
  final _light = PointerLightSource();

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Colourful, high-frequency backdrop so refraction is obvious.
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF0080), Color(0xFF7928CA), Color(0xFF00D4FF)],
              ),
            ),
            child: GridView.count(
              crossAxisCount: 6,
              children: List.generate(
                60,
                (i) => Icon(Icons.star, color: Colors.white.withValues(alpha: 0.18), size: 40),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 260,
              height: 160,
              child: MouseRegion(
                onHover: (e) => _light.update(e.localPosition, const Size(260, 160)),
                child: GlassContainer(
                  material: GlassMaterials.liquid,
                  shape: const GlassShape.roundedRect(32),
                  lightSource: _light,
                  child: const Center(
                    child: Text('Liquid Glass',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: VISUAL VERIFICATION (on-device, replaces unit test for the shader path).**
  Run on an Impeller device/emulator:

  ```bash
  cd example && flutter run -d <android-or-ios-or-windows-device>
  ```

  Confirm by eye (capture screenshots for the user to review):
  - The star grid behind the card is visibly **warped/lensed** through the glass (refraction).
  - There is subtle **colour fringing** at the edges (chromatic aberration).
  - Moving the mouse/finger moves a **specular highlight** across the surface.
  - The rim is brighter than the centre (Fresnel) and corners are rounded cleanly.
  - On web (`flutter run -d chrome`): the card shows the **blur+tint fallback** (no crash, looks intentional).

- [ ] **Step 4: Commit** — `git commit -am "feat: example gallery (flagship liquid glass + pointer light)"`

---

## Self-Review

**Spec coverage (Phase 0 + Phase 1):**
- Package scaffold + shader wiring → Task 1. ✓
- Capability gating + fallback selection → Tasks 3, 4. ✓
- SDF-from-shape (rounded-rect; arbitrary `Path` deferred to a later phase per spec) → Tasks 5, 6, 10. ✓
- Refraction + chromatic aberration + specular + Fresnel + tint → Task 10 (shader) + Task 7 (params). ✓
- Both APIs: `GlassContainer` wrapper present; raw shape entry via `GlassShape`/`GlassClipper` is public (a dedicated `GlassPaint` low-level widget is deferred to Phase 2 — wrapper covers Phase 1 needs). ✓ (noted)
- Pluggable opt-in light (manual default, pointer, stream/gyro adaptor) → Task 9. ✓
- Flagship preset on mobile + fallback elsewhere → Tasks 8, 12, 13. ✓
- `GlassQuality` knob → Task 2 (wiring into sample counts is a Phase 2 shader-loop refinement). ✓ (noted)

**Placeholder scan:** none — every code step is complete.

**Type consistency:** `toShaderFloats(lightDir, cornerRadius, yFlip)` (Task 7) is consumed verbatim by `GlassFilterBuilder.build` (Task 11), whose uniform indices match `glass.frag` (Task 10). `GlassShape.cornerRadius`, `GlassClipper`, `ManualLightSource`/`PointerLightSource`/`StreamLightSource`, `GlassCapabilities`, `resolveGlassRenderPath`, `GlassRenderPath`, `GlassMaterials.liquid/clear` are used consistently across Tasks 6, 9, 11, 12, 13.

**Deferred (out of Phase 0/1, tracked for later phases):** arbitrary-`Path` SDF textures; `GlassQuality` feeding the shader sample loop; dedicated low-level `GlassPaint`; additional presets; desktop/advanced optics; web fallback polish.
