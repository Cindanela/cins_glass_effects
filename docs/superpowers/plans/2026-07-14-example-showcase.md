# Example Showcase Gallery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the example app as a swipeable specimen-per-screen gallery (5 registry shapes + nav-bar fixture + animation page) with switchable backdrops, material chips, and a slider drawer, so glass fixes can be eyeballed on-device.

**Architecture:** Registry-driven `PageView`: a `Specimen` model + list drives a generic `SpecimenPage`; two custom pages (nav bar, animation) plug into the same chrome. All state lives in one `StatefulWidget` (`ShowcasePage`) in `main.dart`; child widgets are stateless, values-in/callbacks-out.

**Tech Stack:** Flutter 3.44 / Dart 3.12, `cins_glass_effects` (path dep), `flutter_test`. No other dependencies.

**Spec:** `docs/superpowers/specs/2026-07-14-example-showcase-design.md`

## Global Constraints

- Branch: `feature/example-showcase` (already checked out). Commit after every task.
- All new files under `example/lib/showcase/` except `main.dart` and `glass_nav_bar.dart` edits; tests under `example/test/`.
- **Run all commands from the `example/` directory** unless a step says otherwise.
- No new dependencies except `flutter_test` (sdk) in the example's `dev_dependencies`.
- No raw literals for spacing/radius/color/duration in chrome widgets — use `ShowcaseTheme` tokens from `example/lib/showcase/theme.dart`.
- Avoid `StatefulWidget` except `ShowcasePage` (root state, approved in spec) and `_ScrollingBackdrop` (owns its auto-scroll ticker).
- The package's public API is the only import from `cins_glass_effects` (barrel import).
- Existing API signatures you will consume (verified against source):
  - `GlassContainer({required Widget child, GlassMaterial material, GlassShape shape, GlassLightSource? lightSource, GlassCapabilities? capabilities})`
  - `AnimatedGlassContainer({required Widget child, GlassMaterial material, GlassShape shape, GlassLightSource? lightSource, GlassCapabilities? capabilities, required Duration duration, Curve curve, VoidCallback? onEnd})`
  - `GlassMaterial.copyWith({double? refraction, chromaticAberration, specular, shininess, fresnel, Color? tint, double? blurSigma, edgeWidth, grain})`
  - Presets: `GlassMaterials.liquid`, `GlassMaterials.frosted`, `GlassMaterials.clear`
  - Shapes: `GlassShape.roundedRect(double)`, `GlassShape.circle()`, `GlassShape.squircle({double exponent})`, `GlassShape.normalizedPolygon(List<Offset>)`, `GlassShape.path(Path Function(Size), {sdfFn, id})`, `a.union(b)`, `a.difference(b)`; all have value equality (safe to rebuild per frame — the SDF cache keys on equality).
  - `harmonicBlobShape({required Offset center, double innerRadius, double outerRadius, int harmonics, int minFrequency, int maxFrequency, int samples, int? seed})`
  - `ShapeSdf.roundedRect(Offset p, Size halfExtent, double radius)` — **p is relative to the rect centre, halfExtent is half-size**; `ShapeSdf.circle(Offset p, double radius)` — p relative to centre.
  - `PointerLightSource()` with `void update(Offset localPosition, Size size)`; it IS a `GlassLightSource`.
  - `Color.a/.r/.g/.b` are doubles 0..1 (Flutter 3.44 color API); `color.withValues(alpha: v)`.

---

### Task 1: Theme tokens + Specimen model and registry

**Files:**
- Modify: `example/pubspec.yaml`
- Create: `example/lib/showcase/theme.dart`
- Create: `example/lib/showcase/specimen.dart`
- Test: `example/test/specimen_test.dart`

**Interfaces:**
- Consumes: package barrel (`GlassShape`, `GlassMaterial`, `GlassMaterials`, `harmonicBlobShape`).
- Produces: `ShowcaseTheme` (all tokens below); `class Specimen { String title; GlassShape Function(Size) shape; GlassMaterial defaultMaterial; String checkNote; }`; `final List<Specimen> specimens` (length 5, order: Rounded rect, Circle, Squircle, Harmonic blob, Star polygon); `List<Offset> starUnitVertices({int points, double innerRadius, double outerRadius})`.

- [ ] **Step 1: Add `flutter_test` to the example's dev_dependencies**

In `example/pubspec.yaml` replace the `dev_dependencies:` block with:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 2: Write the failing test**

Create `example/test/specimen_test.dart`:

```dart
import 'dart:ui';

import 'package:cins_glass_effects_example/showcase/specimen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(300, 300);

  test('registry has the five spec pages with unique titles', () {
    expect(specimens, hasLength(5));
    expect(specimens.map((s) => s.title).toSet(), hasLength(5));
  });

  test('every specimen shape has an SDF (full optics, no fallback)', () {
    for (final s in specimens) {
      expect(s.shape(size).hasSdf, isTrue, reason: s.title);
    }
  });

  test('shape builders are stable: same size twice gives equal shapes', () {
    // GlassContainer rebuilds call shape(size) fresh each frame; equality is
    // what lets SdfTextureCache reuse the bake instead of re-baking.
    for (final s in specimens) {
      expect(s.shape(size), equals(s.shape(size)), reason: s.title);
    }
  });

  test('star polygon is concave: between two arms is outside, centre inside', () {
    final star =
        specimens.firstWhere((s) => s.title == 'Star polygon').shape(size);
    expect(star.sdf(const Offset(220, 90), size), greaterThan(0));
    expect(star.sdf(const Offset(150, 150), size), lessThan(0));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/specimen_test.dart`
Expected: FAIL — cannot resolve `package:cins_glass_effects_example/showcase/specimen.dart`.

- [ ] **Step 4: Write the implementation**

Create `example/lib/showcase/theme.dart`:

```dart
import 'package:flutter/material.dart';

/// Design tokens for the showcase chrome (not the glass itself).
abstract final class ShowcaseTheme {
  // Spacing / radius.
  static const double pad = 16;
  static const double gap = 12;
  static const double controlRadius = 14;
  static const double dotSize = 8;
  static const double dotActiveWidth = 18;
  static const double dotGap = 3;

  // Specimen sizing.
  /// Specimen box side, as a fraction of the screen's shortest side.
  static const double specimenFraction = 0.72;
  static const double animGlassSide = 220;

  /// Keeps page-level controls clear of the chrome's bottom drawer.
  static const double pageBottomInset = 96;

  // Durations.
  static const Duration materialTween = Duration(milliseconds: 350);
  static const Duration driftPeriod = Duration(seconds: 3);
  static const Duration scrollPeriod = Duration(seconds: 8);

  // Chrome colors / text.
  static const Color chromeBg = Color(0x73000000);
  static const Color chromeFg = Colors.white;
  static const TextStyle headerTitle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle controlLabel = TextStyle(
    color: Colors.white70,
    fontSize: 12,
  );
}
```

Create `example/lib/showcase/specimen.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:cins_glass_effects/cins_glass_effects.dart';

/// One gallery entry: a shape to render as glass plus what to eyeball on it.
class Specimen {
  const Specimen({
    required this.title,
    required this.shape,
    required this.checkNote,
    this.defaultMaterial = GlassMaterials.liquid,
  });

  final String title;

  /// Builder rather than a value: the blob needs its centre in the specimen
  /// box's local coordinates, which only exist at layout time.
  final GlassShape Function(Size size) shape;

  final GlassMaterial defaultMaterial;

  /// One-line "what to eyeball" hint, shown in the chrome header.
  final String checkNote;
}

/// Alternating outer/inner vertices of a star in the unit square, starting
/// from the top point.
List<Offset> starUnitVertices({
  int points = 5,
  double innerRadius = 0.22,
  double outerRadius = 0.48,
}) {
  return List.generate(points * 2, (i) {
    final r = i.isEven ? outerRadius : innerRadius;
    final angle = -math.pi / 2 + i * math.pi / points;
    return Offset(0.5 + r * math.cos(angle), 0.5 + r * math.sin(angle));
  });
}

final List<Specimen> specimens = [
  Specimen(
    title: 'Rounded rect',
    checkNote:
        'Analytic shader. Corners must match the clip; no dark hairlines on the sides.',
    shape: (_) => const GlassShape.roundedRect(32),
  ),
  Specimen(
    title: 'Circle',
    checkNote: 'Baked SDF. Rim should be a perfect, even ring.',
    shape: (_) => const GlassShape.circle(),
  ),
  Specimen(
    title: 'Squircle',
    checkNote:
        'Baked SDF. Corners smooth, edge band uniform all the way around.',
    shape: (_) => const GlassShape.squircle(),
  ),
  Specimen(
    title: 'Harmonic blob',
    checkNote: 'Baked SDF. Curves smooth — no staircase edges.',
    shape: (size) => harmonicBlobShape(
      center: Offset(size.width / 2, size.height / 2),
      innerRadius: size.shortestSide * 0.30,
      outerRadius: size.shortestSide * 0.46,
      seed: 7,
    ),
  ),
  Specimen(
    title: 'Star polygon',
    checkNote: 'Baked SDF, concave. Notches must show correct edge optics.',
    shape: (_) => GlassShape.normalizedPolygon(starUnitVertices()),
  ),
];
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/specimen_test.dart`
Expected: 4 tests PASS.

- [ ] **Step 6: Commit**

```powershell
git add ../example
git commit -m "feat(example): showcase theme tokens + specimen model and registry"
```

---

### Task 2: Switchable backdrops

**Files:**
- Create: `example/lib/showcase/backdrops.dart`
- Test: `example/test/backdrops_test.dart`

**Interfaces:**
- Consumes: `ShowcaseTheme`.
- Produces: `enum ShowcaseBackdrop { gradient, plain, scrolling }` with `String label`, `IconData icon`, `ShowcaseBackdrop get next`; `class BackdropView extends StatelessWidget { BackdropView({required ShowcaseBackdrop backdrop}) }` with a public `backdrop` field (tests and chrome read it).

- [ ] **Step 1: Write the failing test**

Create `example/test/backdrops_test.dart`:

```dart
import 'package:cins_glass_effects_example/showcase/backdrops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('next cycles through all backdrops and wraps', () {
    expect(ShowcaseBackdrop.gradient.next, ShowcaseBackdrop.plain);
    expect(ShowcaseBackdrop.plain.next, ShowcaseBackdrop.scrolling);
    expect(ShowcaseBackdrop.scrolling.next, ShowcaseBackdrop.gradient);
  });

  testWidgets('every backdrop builds and survives a frame of animation',
      (tester) async {
    for (final b in ShowcaseBackdrop.values) {
      await tester.pumpWidget(MaterialApp(home: BackdropView(backdrop: b)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BackdropView), findsOneWidget);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/backdrops_test.dart`
Expected: FAIL — cannot resolve `backdrops.dart`.

- [ ] **Step 3: Write the implementation**

Create `example/lib/showcase/backdrops.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The three things glass can sit on — each makes a different defect visible:
/// gradient = refraction, plain = hairlines/tint, scrolling = backdrop tracking.
enum ShowcaseBackdrop {
  gradient('Gradient', Icons.gradient),
  plain('Plain', Icons.crop_square),
  scrolling('Scrolling', Icons.swap_vert);

  const ShowcaseBackdrop(this.label, this.icon);

  final String label;
  final IconData icon;

  ShowcaseBackdrop get next => values[(index + 1) % values.length];
}

class BackdropView extends StatelessWidget {
  const BackdropView({super.key, required this.backdrop});

  final ShowcaseBackdrop backdrop;

  @override
  Widget build(BuildContext context) => switch (backdrop) {
        ShowcaseBackdrop.gradient => const _GradientBackdrop(),
        ShowcaseBackdrop.plain => const _PlainBackdrop(),
        ShowcaseBackdrop.scrolling => const _ScrollingBackdrop(),
      };
}

/// Colourful, high-frequency backdrop so refraction is obvious.
class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF0080), Color(0xFF7928CA), Color(0xFF00D4FF)],
        ),
      ),
      child: GridView.count(
        crossAxisCount: 6,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          60,
          (i) => Icon(
            Icons.star,
            color: Colors.white.withValues(alpha: 0.18),
            size: 40,
          ),
        ),
      ),
    );
  }
}

/// Light and quiet: dark hairlines and tint errors have nowhere to hide.
class _PlainBackdrop extends StatelessWidget {
  const _PlainBackdrop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F2F4),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(ShowcaseTheme.pad),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: ShowcaseTheme.gap),
          child: Text(
            'The quick brown fox jumps over the lazy dog — line $i',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.35),
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

const _cardColors = [
  Color(0xFFFF0080),
  Color(0xFF7928CA),
  Color(0xFF00D4FF),
  Color(0xFF00E5A0),
  Color(0xFFFFB300),
];

/// Auto-scrolls (ping-pong) so moving content passes under the glass hands-free.
/// Auto rather than manual: the PageView above it claims drag gestures, so a
/// user-scrolled list here would never receive them.
class _ScrollingBackdrop extends StatefulWidget {
  const _ScrollingBackdrop();

  @override
  State<_ScrollingBackdrop> createState() => _ScrollingBackdropState();
}

class _ScrollingBackdropState extends State<_ScrollingBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: ShowcaseTheme.scrollPeriod,
  )..repeat();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cycle.addListener(_drive);
  }

  void _drive() {
    if (!_scroll.hasClients) return;
    final range = _scroll.position.maxScrollExtent;
    // Smooth ping-pong: 0 → range → 0 over one controller cycle.
    final t = 0.5 - 0.5 * math.cos(_cycle.value * 2 * math.pi);
    _scroll.jumpTo(range * t);
  }

  @override
  void dispose() {
    _cycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF101014),
      child: ListView.builder(
        controller: _scroll,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(ShowcaseTheme.pad),
        itemCount: 40,
        itemBuilder: (_, i) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: ShowcaseTheme.pad),
          decoration: BoxDecoration(
            color: _cardColors[i % _cardColors.length],
            borderRadius: BorderRadius.circular(ShowcaseTheme.controlRadius),
          ),
          child: Center(
            child: Text(
              'Card $i',
              style: const TextStyle(color: Colors.white70, fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/backdrops_test.dart`
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add ../example
git commit -m "feat(example): three switchable showcase backdrops"
```

---

### Task 3: Material chips + slider drawer

**Files:**
- Create: `example/lib/showcase/controls.dart`
- Test: `example/test/controls_test.dart`

**Interfaces:**
- Consumes: `ShowcaseTheme`, `GlassMaterial`, `GlassMaterials`.
- Produces: `typedef ShowcasePreset = ({String label, GlassMaterial material})`; `const List<ShowcasePreset> showcasePresets` (Liquid, Frosted, Clear — in that order); `class ControlsDrawer extends StatelessWidget` with constructor `({required GlassMaterial material, required int presetIndex, required bool expanded, required ValueChanged<int> onPresetSelected, required ValueChanged<GlassMaterial> onMaterialChanged, required VoidCallback onToggleExpanded})`. Slider row order (tests depend on it): edge width, refraction, aberration, blur, grain, tint alpha.

- [ ] **Step 1: Write the failing test**

Create `example/test/controls_test.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/showcase/controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    GlassMaterial material = GlassMaterials.liquid,
    int presetIndex = 0,
    bool expanded = false,
    ValueChanged<int>? onPreset,
    ValueChanged<GlassMaterial>? onMaterial,
    VoidCallback? onToggle,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ControlsDrawer(
          material: material,
          presetIndex: presetIndex,
          expanded: expanded,
          onPresetSelected: onPreset ?? (_) {},
          onMaterialChanged: onMaterial ?? (_) {},
          onToggleExpanded: onToggle ?? () {},
        ),
      ),
    ));
  }

  testWidgets('preset chip tap reports its index', (tester) async {
    int? selected;
    await pump(tester, onPreset: (i) => selected = i);
    await tester.tap(find.text('Frosted'));
    expect(selected, 1);
  });

  testWidgets('collapsed hides sliders, expanded shows all six',
      (tester) async {
    await pump(tester);
    expect(find.byType(Slider), findsNothing);
    await pump(tester, expanded: true);
    expect(find.byType(Slider), findsNWidgets(6));
  });

  testWidgets('edge width slider emits a copyWith-modified material',
      (tester) async {
    GlassMaterial? changed;
    await pump(tester, expanded: true, onMaterial: (m) => changed = m);
    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    expect(changed, isNotNull);
    expect(changed!.edgeWidth, isNot(GlassMaterials.liquid.edgeWidth));
    expect(changed!.refraction, GlassMaterials.liquid.refraction);
  });

  testWidgets('reset restores the selected preset', (tester) async {
    GlassMaterial? changed;
    await pump(
      tester,
      expanded: true,
      material: GlassMaterials.liquid.copyWith(edgeWidth: 40),
      onMaterial: (m) => changed = m,
    );
    await tester.tap(find.text('Reset'));
    expect(changed, GlassMaterials.liquid);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controls_test.dart`
Expected: FAIL — cannot resolve `controls.dart`.

- [ ] **Step 3: Write the implementation**

Create `example/lib/showcase/controls.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

typedef ShowcasePreset = ({String label, GlassMaterial material});

const List<ShowcasePreset> showcasePresets = [
  (label: 'Liquid', material: GlassMaterials.liquid),
  (label: 'Frosted', material: GlassMaterials.frosted),
  (label: 'Clear', material: GlassMaterials.clear),
];

/// Material chips + collapsible slider drawer. Stateless: current values come
/// in, changes go out through callbacks. Values are shown numerically so good
/// numbers can be read back off the device for preset re-tuning.
class ControlsDrawer extends StatelessWidget {
  const ControlsDrawer({
    super.key,
    required this.material,
    required this.presetIndex,
    required this.expanded,
    required this.onPresetSelected,
    required this.onMaterialChanged,
    required this.onToggleExpanded,
  });

  final GlassMaterial material;
  final int presetIndex;
  final bool expanded;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<GlassMaterial> onMaterialChanged;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        ShowcaseTheme.pad, 0, ShowcaseTheme.pad, ShowcaseTheme.pad),
      padding: const EdgeInsets.all(ShowcaseTheme.gap),
      decoration: BoxDecoration(
        color: ShowcaseTheme.chromeBg,
        borderRadius: BorderRadius.circular(ShowcaseTheme.controlRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: ShowcaseTheme.gap / 2,
                  children: [
                    for (var i = 0; i < showcasePresets.length; i++)
                      ChoiceChip(
                        label: Text(showcasePresets[i].label),
                        selected: i == presetIndex,
                        onSelected: (_) => onPresetSelected(i),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(expanded ? Icons.expand_more : Icons.tune),
                color: ShowcaseTheme.chromeFg,
                tooltip: 'Optics sliders',
                onPressed: onToggleExpanded,
              ),
            ],
          ),
          if (expanded) ...[
            _slider('edge width', material.edgeWidth, 40,
                (v) => onMaterialChanged(material.copyWith(edgeWidth: v))),
            _slider('refraction', material.refraction, 30,
                (v) => onMaterialChanged(material.copyWith(refraction: v))),
            _slider('aberration', material.chromaticAberration, 8,
                (v) => onMaterialChanged(
                    material.copyWith(chromaticAberration: v))),
            _slider('blur', material.blurSigma, 20,
                (v) => onMaterialChanged(material.copyWith(blurSigma: v))),
            _slider('grain', material.grain, 1,
                (v) => onMaterialChanged(material.copyWith(grain: v))),
            _slider('tint alpha', material.tint.a, 0.4,
                (v) => onMaterialChanged(material.copyWith(
                    tint: material.tint.withValues(alpha: v)))),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    onMaterialChanged(showcasePresets[presetIndex].material),
                child: const Text('Reset'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slider(
      String label, double value, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: ShowcaseTheme.controlLabel),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, max).toDouble(),
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: ShowcaseTheme.controlLabel,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controls_test.dart`
Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add ../example
git commit -m "feat(example): material chips + optics slider drawer"
```

---

### Task 4: Generic SpecimenPage

**Files:**
- Create: `example/lib/showcase/specimen_page.dart`
- Test: `example/test/specimen_page_test.dart`

**Interfaces:**
- Consumes: `Specimen`, `specimens`, `ShowcaseTheme`, `GlassContainer`, `PointerLightSource`.
- Produces: `class SpecimenPage extends StatelessWidget` with constructor `({required Specimen specimen, required GlassMaterial material, PointerLightSource? pointerLight})`.

- [ ] **Step 1: Write the failing test**

Create `example/test/specimen_page_test.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/showcase/specimen.dart';
import 'package:cins_glass_effects_example/showcase/specimen_page.dart';
import 'package:cins_glass_effects_example/showcase/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the specimen as glass with the given material',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SpecimenPage(
        specimen: specimens.first,
        material: GlassMaterials.frosted,
      ),
    ));
    await tester.pump();
    final gc = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(gc.material, GlassMaterials.frosted);
  });

  testWidgets('specimen box is square at the themed fraction', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SpecimenPage(
        specimen: specimens.first,
        material: GlassMaterials.liquid,
      ),
    ));
    await tester.pump();
    // Default test surface is 800×600 → shortest side 600.
    final box = tester.getSize(find.byType(GlassContainer));
    expect(box.width, box.height);
    expect(box.width, closeTo(600 * ShowcaseTheme.specimenFraction, 1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/specimen_page_test.dart`
Expected: FAIL — cannot resolve `specimen_page.dart`.

- [ ] **Step 3: Write the implementation**

Create `example/lib/showcase/specimen_page.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/widgets.dart';

import 'specimen.dart';
import 'theme.dart';

/// One specimen, centred and big, over whatever backdrop the chrome chose.
/// Dragging a finger (or hovering a mouse) over the glass moves the light.
class SpecimenPage extends StatelessWidget {
  const SpecimenPage({
    super.key,
    required this.specimen,
    required this.material,
    this.pointerLight,
  });

  final Specimen specimen;
  final GlassMaterial material;
  final PointerLightSource? pointerLight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            constraints.biggest.shortestSide * ShowcaseTheme.specimenFraction;
        final size = Size(side, side);
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: Listener(
              onPointerHover: (e) => pointerLight?.update(e.localPosition, size),
              onPointerMove: (e) => pointerLight?.update(e.localPosition, size),
              child: GlassContainer(
                material: material,
                shape: specimen.shape(size),
                lightSource: pointerLight,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/specimen_page_test.dart`
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add ../example
git commit -m "feat(example): generic specimen page"
```

---

### Task 5: Nav bar + FAB page with separate/union toggle

**Files:**
- Modify: `example/lib/glass_nav_bar.dart` (make dimension constants and icon list public)
- Create: `example/lib/showcase/nav_bar_page.dart`
- Test: `example/test/nav_bar_page_test.dart`

**Interfaces:**
- Consumes: `GlassNavBar`, `ShapeSdf`, `GlassShape.path`, `.union`, `ShowcaseTheme`.
- Produces: public constants in `glass_nav_bar.dart`: `kNavBarHeight = 58.0`, `kNavFabSize = 70.0`, `kNavHoleRadius = 43.0`, `kNavCornerRadius = 29.0`, `kNavIconSize = 28.0`, `kNavFabIconSize = 47.6`, `kNavMiddleGap = kNavFabSize + 24.0 * 2`, `const List<IconData> kNavIcons` (the 4 existing icons). In `nav_bar_page.dart`: `GlassShape navBarUnionShape()`; `class NavBarPage extends StatelessWidget` with `({required bool union, required ValueChanged<bool> onUnionChanged})`; `class UnionNavBar extends StatelessWidget` (no params).

- [ ] **Step 1: Make the nav bar dimensions public**

In `example/lib/glass_nav_bar.dart`:
- Rename `_barHeight` → `kNavBarHeight`, `_fabSize` → `kNavFabSize`, `_holeRadius` → `kNavHoleRadius`, `_cornerRadius` → `kNavCornerRadius`, `_navIconSize` → `kNavIconSize`, `_fabIconSize` → `kNavFabIconSize`, `_middleGap` → `kNavMiddleGap` (update every use and the comments' wording where they reference the old names).
- Move the private `static const _icons` list out of the class to a top-level `const List<IconData> kNavIcons = <IconData>[Icons.grid_view_rounded, Icons.calendar_month_rounded, Icons.list_rounded, Icons.bar_chart_rounded];` and update `GlassNavBar.build` to use `kNavIcons`.

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Write the failing test**

Create `example/test/nav_bar_page_test.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/showcase/nav_bar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester,
      {required bool union, ValueChanged<bool>? onChanged}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NavBarPage(union: union, onUnionChanged: onChanged ?? (_) {}),
      ),
    ));
  }

  testWidgets('separate mode: bar and FAB are two glass widgets',
      (tester) async {
    await pump(tester, union: false);
    expect(find.byType(GlassContainer), findsNWidgets(2));
  });

  testWidgets('union mode: one glass slab', (tester) async {
    await pump(tester, union: true);
    expect(find.byType(GlassContainer), findsOneWidget);
    final gc = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(gc.shape.hasSdf, isTrue);
  });

  testWidgets('toggle reports the new selection', (tester) async {
    bool? selected;
    await pump(tester, union: false, onChanged: (v) => selected = v);
    await tester.tap(find.text('Union'));
    expect(selected, isTrue);
  });

  test('union shape geometry: FAB area is glass, no hole', () {
    final shape = navBarUnionShape();
    const size = Size(360, 70);
    // FAB centre and its overhang above the bar band are inside the glass.
    expect(shape.sdf(const Offset(180, 35), size), lessThan(0));
    expect(shape.sdf(const Offset(180, 2), size), lessThan(0));
    // Above the bar band but away from the FAB is air.
    expect(shape.sdf(const Offset(20, 2), size), greaterThan(0));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/nav_bar_page_test.dart`
Expected: FAIL — cannot resolve `nav_bar_page.dart`.

- [ ] **Step 4: Write the implementation**

Create `example/lib/showcase/nav_bar_page.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import '../glass_nav_bar.dart';
import 'theme.dart';

Offset _centre(Size size) => Offset(size.width / 2, size.height / 2);

/// One glass slab: bar ∪ FAB circle — the candidate fix for the doubled rim
/// and rectangular seam where two stacked backdrop filters overlap
/// (WORKLOG 2026-07-13, issue 4).
GlassShape navBarUnionShape() {
  final bar = GlassShape.path(
    (size) {
      final inset = (size.height - kNavBarHeight) / 2;
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, inset, size.width, kNavBarHeight),
          const Radius.circular(kNavCornerRadius),
        ));
    },
    sdfFn: (p, size) => ShapeSdf.roundedRect(
      p - _centre(size),
      Size(size.width / 2, kNavBarHeight / 2),
      kNavCornerRadius,
    ),
    id: 'showcase-union-bar',
  );
  final fab = GlassShape.path(
    (size) => Path()
      ..addOval(Rect.fromCircle(center: _centre(size), radius: kNavFabSize / 2)),
    sdfFn: (p, size) => ShapeSdf.circle(p - _centre(size), kNavFabSize / 2),
    id: 'showcase-union-fab',
  );
  return bar.union(fab);
}

/// The nav-bar fixture: `Separate` reproduces the two-widget composition from
/// the real app (and its seam bug); `Union` renders the same silhouette as one
/// GlassContainer.
class NavBarPage extends StatelessWidget {
  const NavBarPage({
    super.key,
    required this.union,
    required this.onUnionChanged,
  });

  final bool union;
  final ValueChanged<bool> onUnionChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ShowcaseTheme.pad,
              ShowcaseTheme.pad, ShowcaseTheme.pad, ShowcaseTheme.pageBottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Separate')),
                  ButtonSegment(value: true, label: Text('Union')),
                ],
                selected: {union},
                onSelectionChanged: (s) => onUnionChanged(s.single),
              ),
              const SizedBox(height: ShowcaseTheme.pad),
              if (union)
                const UnionNavBar()
              else
                // Static fixture — taps aren't the point here.
                GlassNavBar(currentIndex: 0, onTap: (_) {}, onAdd: () {}),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same bar + FAB silhouette as [GlassNavBar], but as ONE GlassContainer.
class UnionNavBar extends StatelessWidget {
  const UnionNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kNavFabSize,
      child: GlassContainer(
        material: GlassMaterials.clear,
        shape: navBarUnionShape(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                for (final (i, icon) in kNavIcons.indexed) ...[
                  Expanded(
                    child: Center(
                      child: Icon(
                        icon,
                        size: kNavIconSize,
                        color: i == 0 ? Colors.white : Colors.white60,
                      ),
                    ),
                  ),
                  if (i == 1) const SizedBox(width: kNavMiddleGap),
                ],
              ],
            ),
            const Icon(
              Icons.add_rounded,
              size: kNavFabIconSize,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/nav_bar_page_test.dart`
Expected: 4 tests PASS.

- [ ] **Step 6: Commit**

```powershell
git add ../example
git commit -m "feat(example): nav bar fixture page with separate/union toggle"
```

---

### Task 6: Animation page

**Files:**
- Create: `example/lib/showcase/animation_page.dart`
- Test: `example/test/animation_page_test.dart`

**Interfaces:**
- Consumes: `AnimatedGlassContainer`, `showcasePresets`, `ShowcaseTheme`.
- Produces: `class AnimationPage extends StatelessWidget` with constructor `({required int presetIndex, required bool driftEnabled, required bool driftRight, required VoidCallback onTapGlass, required ValueChanged<bool> onDriftToggled, required VoidCallback onDriftLegComplete})`.

- [ ] **Step 1: Write the failing test**

Create `example/test/animation_page_test.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/showcase/animation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int presetIndex = 0,
    bool driftEnabled = false,
    VoidCallback? onTap,
    ValueChanged<bool>? onDrift,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AnimationPage(
          presetIndex: presetIndex,
          driftEnabled: driftEnabled,
          driftRight: false,
          onTapGlass: onTap ?? () {},
          onDriftToggled: onDrift ?? (_) {},
          onDriftLegComplete: () {},
        ),
      ),
    ));
  }

  testWidgets('material follows presetIndex and tap invokes callback',
      (tester) async {
    var taps = 0;
    await pump(tester, presetIndex: 1, onTap: () => taps++);
    final agc = tester
        .widget<AnimatedGlassContainer>(find.byType(AnimatedGlassContainer));
    expect(agc.material, GlassMaterials.frosted);
    await tester.tap(find.byType(AnimatedGlassContainer));
    expect(taps, 1);
  });

  testWidgets('drift chip reports toggling on', (tester) async {
    bool? drifting;
    await pump(tester, onDrift: (v) => drifting = v);
    await tester.tap(find.text('Drift'));
    expect(drifting, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/animation_page_test.dart`
Expected: FAIL — cannot resolve `animation_page.dart`.

- [ ] **Step 3: Write the implementation**

Create `example/lib/showcase/animation_page.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import 'controls.dart';
import 'theme.dart';

/// Animation checks: tap the glass to tween between material presets; enable
/// Drift to slide the panel side to side — grain must travel with the widget
/// (it is anchored in widget-local coords), never swim against it.
class AnimationPage extends StatelessWidget {
  const AnimationPage({
    super.key,
    required this.presetIndex,
    required this.driftEnabled,
    required this.driftRight,
    required this.onTapGlass,
    required this.onDriftToggled,
    required this.onDriftLegComplete,
  });

  final int presetIndex;
  final bool driftEnabled;
  final bool driftRight;
  final VoidCallback onTapGlass;
  final ValueChanged<bool> onDriftToggled;

  /// Called when one left↔right leg finishes; the owner flips [driftRight]
  /// while [driftEnabled] to ping-pong.
  final VoidCallback onDriftLegComplete;

  @override
  Widget build(BuildContext context) {
    final preset = showcasePresets[presetIndex];
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(ShowcaseTheme.pad),
              child: AnimatedAlign(
                alignment: !driftEnabled
                    ? Alignment.center
                    : (driftRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft),
                duration: ShowcaseTheme.driftPeriod,
                onEnd: onDriftLegComplete,
                child: GestureDetector(
                  onTap: onTapGlass,
                  child: SizedBox(
                    width: ShowcaseTheme.animGlassSide,
                    height: ShowcaseTheme.animGlassSide,
                    child: AnimatedGlassContainer(
                      duration: ShowcaseTheme.materialTween,
                      material: preset.material,
                      shape: const GlassShape.roundedRect(32),
                      child: Center(
                        child: Text(
                          '${preset.label}\ntap to tween',
                          textAlign: TextAlign.center,
                          style: ShowcaseTheme.headerTitle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(bottom: ShowcaseTheme.pageBottomInset),
            child: FilterChip(
              label: const Text('Drift'),
              selected: driftEnabled,
              onSelected: onDriftToggled,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/animation_page_test.dart`
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```powershell
git add ../example
git commit -m "feat(example): animation page - material tween + drift grain check"
```

---

### Task 7: ShowcasePage chrome + main.dart wiring

**Files:**
- Modify: `example/lib/main.dart` (full rewrite — the old `GlassDemoPage` is replaced by the showcase)
- Test: `example/test/showcase_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: `GlassGalleryApp` (unchanged name, used by tests), `ShowcasePage` (StatefulWidget owning ALL state: `_pageIndex`, `_backdrop`, `_presetIndex`, `_material`, `_drawerExpanded`, `_navBarUnion`, `_animPresetIndex`, `_driftEnabled`, `_driftRight`).

- [ ] **Step 1: Write the failing test**

Create `example/test/showcase_test.dart`:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/main.dart';
import 'package:cins_glass_effects_example/showcase/backdrops.dart';
import 'package:cins_glass_effects_example/showcase/specimen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots on the first specimen with title and check note',
      (tester) async {
    await tester.pumpWidget(const GlassGalleryApp());
    await tester.pump();
    expect(find.text(specimens.first.title), findsOneWidget);
    expect(find.text(specimens.first.checkNote), findsOneWidget);
  });

  testWidgets('swiping walks every page through to Animation',
      (tester) async {
    await tester.pumpWidget(const GlassGalleryApp());
    await tester.pump();
    for (var i = 1; i < specimens.length; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text(specimens[i].title), findsOneWidget);
    }
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Nav bar + FAB'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Animation'), findsOneWidget);
  });

  testWidgets('material chip swaps the specimen material', (tester) async {
    await tester.pumpWidget(const GlassGalleryApp());
    await tester.pump();
    await tester.tap(find.text('Frosted'));
    await tester.pump();
    final gc = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(gc.material, GlassMaterials.frosted);
  });

  testWidgets('backdrop button cycles the backdrop', (tester) async {
    await tester.pumpWidget(const GlassGalleryApp());
    await tester.pump();
    expect(
      tester.widget<BackdropView>(find.byType(BackdropView)).backdrop,
      ShowcaseBackdrop.gradient,
    );
    await tester.tap(find.byIcon(ShowcaseBackdrop.gradient.icon));
    await tester.pump();
    expect(
      tester.widget<BackdropView>(find.byType(BackdropView)).backdrop,
      ShowcaseBackdrop.plain,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/showcase_test.dart`
Expected: FAIL — `GlassGalleryApp` still builds the old `GlassDemoPage` (no titles/chips found).

- [ ] **Step 3: Rewrite `example/lib/main.dart`**

Replace the entire file with:

```dart
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import 'showcase/animation_page.dart';
import 'showcase/backdrops.dart';
import 'showcase/controls.dart';
import 'showcase/nav_bar_page.dart';
import 'showcase/specimen.dart';
import 'showcase/specimen_page.dart';
import 'showcase/theme.dart';

void main() => runApp(const GlassGalleryApp());

class GlassGalleryApp extends StatelessWidget {
  const GlassGalleryApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ShowcasePage(),
      );
}

/// The gallery: a page per specimen over a switchable backdrop, with shared
/// chrome (header, page dots, material controls). Owns ALL showcase state —
/// every child is stateless (values in, callbacks out).
class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key});

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  final PageController _pages = PageController();
  final PointerLightSource _light = PointerLightSource();

  int _pageIndex = 0;
  ShowcaseBackdrop _backdrop = ShowcaseBackdrop.gradient;
  int _presetIndex = 0;
  GlassMaterial _material = showcasePresets.first.material;
  bool _drawerExpanded = false;
  bool _navBarUnion = false;
  int _animPresetIndex = 0;
  bool _driftEnabled = false;
  bool _driftRight = false;

  int get _pageCount => specimens.length + 2;
  int get _navBarPage => specimens.length;

  @override
  void dispose() {
    _pages.dispose();
    _light.dispose();
    super.dispose();
  }

  String get _title {
    if (_pageIndex < specimens.length) return specimens[_pageIndex].title;
    return _pageIndex == _navBarPage ? 'Nav bar + FAB' : 'Animation';
  }

  String get _checkNote {
    if (_pageIndex < specimens.length) return specimens[_pageIndex].checkNote;
    return _pageIndex == _navBarPage
        ? 'Separate reproduces the doubled rim + seam; Union is the one-slab candidate fix.'
        : 'Tap tweens the material. Drift: grain must travel with the glass, not swim.';
  }

  Widget _page(int index) {
    if (index < specimens.length) {
      return SpecimenPage(
        specimen: specimens[index],
        material: _material,
        pointerLight: _light,
      );
    }
    if (index == _navBarPage) {
      return NavBarPage(
        union: _navBarUnion,
        onUnionChanged: (v) => setState(() => _navBarUnion = v),
      );
    }
    return AnimationPage(
      presetIndex: _animPresetIndex,
      driftEnabled: _driftEnabled,
      driftRight: _driftRight,
      onTapGlass: () => setState(() =>
          _animPresetIndex = (_animPresetIndex + 1) % showcasePresets.length),
      onDriftToggled: (v) => setState(() {
        _driftEnabled = v;
        _driftRight = v;
      }),
      onDriftLegComplete: () {
        if (_driftEnabled) setState(() => _driftRight = !_driftRight);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropView(backdrop: _backdrop),
          PageView.builder(
            controller: _pages,
            itemCount: _pageCount,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (_, i) => _page(i),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  title: _title,
                  note: _checkNote,
                  backdrop: _backdrop,
                  onBackdropCycled: () =>
                      setState(() => _backdrop = _backdrop.next),
                ),
                _PageDots(count: _pageCount, index: _pageIndex),
                const Spacer(),
                ControlsDrawer(
                  material: _material,
                  presetIndex: _presetIndex,
                  expanded: _drawerExpanded,
                  onPresetSelected: (i) => setState(() {
                    _presetIndex = i;
                    _material = showcasePresets[i].material;
                  }),
                  onMaterialChanged: (m) => setState(() => _material = m),
                  onToggleExpanded: () =>
                      setState(() => _drawerExpanded = !_drawerExpanded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.note,
    required this.backdrop,
    required this.onBackdropCycled,
  });

  final String title;
  final String note;
  final ShowcaseBackdrop backdrop;
  final VoidCallback onBackdropCycled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          ShowcaseTheme.pad, ShowcaseTheme.pad, ShowcaseTheme.pad, 0),
      padding: const EdgeInsets.all(ShowcaseTheme.gap),
      decoration: BoxDecoration(
        color: ShowcaseTheme.chromeBg,
        borderRadius: BorderRadius.circular(ShowcaseTheme.controlRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ShowcaseTheme.headerTitle),
                Text(note, style: ShowcaseTheme.controlLabel),
              ],
            ),
          ),
          IconButton(
            icon: Icon(backdrop.icon),
            color: ShowcaseTheme.chromeFg,
            tooltip: 'Backdrop: ${backdrop.label}',
            onPressed: onBackdropCycled,
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: ShowcaseTheme.gap),
      padding: const EdgeInsets.symmetric(
          horizontal: ShowcaseTheme.gap, vertical: ShowcaseTheme.dotGap),
      decoration: BoxDecoration(
        color: ShowcaseTheme.chromeBg,
        borderRadius: BorderRadius.circular(ShowcaseTheme.dotSize),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: ShowcaseTheme.materialTween,
              margin:
                  const EdgeInsets.symmetric(horizontal: ShowcaseTheme.dotGap),
              width: i == index
                  ? ShowcaseTheme.dotActiveWidth
                  : ShowcaseTheme.dotSize,
              height: ShowcaseTheme.dotSize,
              decoration: BoxDecoration(
                color: i == index ? Colors.white : Colors.white38,
                borderRadius:
                    BorderRadius.circular(ShowcaseTheme.dotSize / 2),
              ),
            ),
        ],
      ),
    );
  }
}
```

Delete nothing else — `glass_nav_bar.dart` stays (used by `NavBarPage`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/showcase_test.dart`
Expected: 4 tests PASS.

- [ ] **Step 5: Run the whole example test suite**

Run: `flutter test`
Expected: all tests PASS (specimen, backdrops, controls, specimen_page, nav_bar_page, animation_page, showcase).

- [ ] **Step 6: Commit**

```powershell
git add ../example
git commit -m "feat(example): showcase chrome - PageView, header, dots, wiring"
```

---

### Task 8: Full verification + docs

**Files:**
- Modify: `WORKLOG.md` (repo root)

- [ ] **Step 1: Analyze both projects**

From the repo root: `flutter analyze`
From `example/`: `flutter analyze`
Expected: No issues found (both).

- [ ] **Step 2: Run both test suites**

From the repo root: `flutter test`
Expected: 86 tests pass (package suite untouched).
From `example/`: `flutter test`
Expected: all example tests pass.

- [ ] **Step 3: Add a WORKLOG entry**

Prepend under `# Worklog` in `WORKLOG.md` (adjust bullets to match reality if anything changed during implementation):

```markdown
## 2026-07-14 — Example showcase gallery (tooling for the visual-fix sessions)

- Rebuilt `example/` as a swipeable specimen gallery: 5 registry shapes (rounded
  rect, circle, squircle, seeded harmonic blob, concave star) + nav-bar fixture +
  animation page, one per screen, registry-driven (`showcase/specimen.dart`).
- Shared chrome: 3 switchable backdrops (gradient / plain-light / auto-scrolling
  cards), material chips, collapsible optics slider drawer with live values (for
  on-device preset re-tuning after the dpr fix), header check-notes per page.
- Nav-bar page toggles separate widgets vs `bar.union(circle)` — the A/B for
  WORKLOG issue 4. Animation page: material tween + drift (grain anchoring check).
- All showcase state in one root StatefulWidget; example got `flutter_test` and
  its own widget-test suite.
```

- [ ] **Step 4: Commit**

From the repo root:

```powershell
git add WORKLOG.md
git commit -m "docs: worklog entry for the example showcase gallery"
```
