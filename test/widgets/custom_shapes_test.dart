import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Centre of a surface of [size].
Offset _centre(Size size) => Offset(size.width / 2, size.height / 2);

/// A rounded bar with a circular hole punched in the centre — the silhouette
/// of `subscription_tracker`'s navigation bar (a real consumer shape). Built
/// purely from the SDF model: `roundedRect − circle`, so the hole rim is an
/// exact, optically-correct edge rather than a special case.
GlassShape barWithHole({double cornerRadius = 24, double holeRadius = 28}) {
  final bar = GlassShape.roundedRect(cornerRadius);
  final hole = GlassShape.path(
    (size) => Path()
      ..addOval(Rect.fromCircle(center: _centre(size), radius: holeRadius)),
    sdfFn: (p, size) => ShapeSdf.circle(p - _centre(size), holeRadius),
    id: 'hole-$holeRadius',
  );
  return bar.difference(hole);
}

void main() {
  group('bar-with-hole geometry', () {
    const size = Size(300, 64); // wide, short bar
    final shape = barWithHole();

    test('clip path keeps the bar body but removes the hole', () {
      final path = shape.clipPath(size);
      expect(path.contains(const Offset(20, 32)), isTrue); // solid bar
      expect(path.contains(const Offset(150, 32)), isFalse); // hole centre
    });

    test('sdf is negative on the bar, positive in the hole', () {
      expect(shape.sdf(const Offset(20, 32), size), lessThan(0)); // inside glass
      expect(shape.sdf(const Offset(150, 32), size), greaterThan(0)); // in the hole
    });

    test('sdf is ~0 on the hole rim, so the optics get a real edge there', () {
      final onRim = _centre(size) + const Offset(28, 0); // hole radius out
      expect(shape.sdf(onRim, size), closeTo(0, 1e-6));
    });

    test('composed shapes are not shader-representable -> use the fallback', () {
      expect(shape.shaderRepresentable, isFalse);
    });
  });

  testWidgets('GlassContainer renders a bar-with-hole shape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const ColoredBox(color: Colors.teal),
            Center(
              child: SizedBox(
                width: 300,
                height: 64,
                child: GlassContainer(
                  capabilities:
                      const GlassCapabilities(shaderFiltersSupported: false),
                  material: GlassMaterials.liquid,
                  shape: barWithHole(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ClipPath), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('arbitrary path with no SDF still renders via the fallback',
      (tester) async {
    // The fallback drives its rim from clipPath, never sdf, so a shape with no
    // analytic SDF must render without throwing.
    final triangle = GlassShape.path(
      (size) => Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const ColoredBox(color: Colors.indigo),
            GlassContainer(
              capabilities:
                  const GlassCapabilities(shaderFiltersSupported: false),
              material: GlassMaterials.clear,
              shape: triangle,
              child: const SizedBox(width: 100, height: 100),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
