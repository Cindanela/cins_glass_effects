import 'dart:ui';

import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SdfField.sample', () {
    test('grid cells hold the shape\'s exact signed distance', () {
      const shape = GlassShape.roundedRect(12);
      const size = Size(100, 100);
      final field = SdfField.sample(shape, size, resolution: 32);

      // Re-derive the texel centre and compare against the shape's SDF.
      const x = 8, y = 20;
      final px = (x + 0.5) / field.width * size.width;
      final py = (y + 0.5) / field.height * size.height;
      expect(field.distanceAt(x, y), closeTo(shape.sdf(Offset(px, py), size), 1e-9));
    });

    test('keeps texels square for a non-square size', () {
      final field = SdfField.sample(
        const GlassShape.roundedRect(8),
        const Size(200, 100),
        resolution: 64,
      );
      expect(field.width, 64);
      expect(field.height, 32); // half the aspect
    });

    test('sign is negative inside, positive outside', () {
      const shape = GlassShape.circle();
      const size = Size(80, 80);
      final field = SdfField.sample(shape, size, resolution: 16);
      // Centre cell -> inside; corner cell -> outside the inscribed circle.
      expect(field.distanceAt(8, 8), lessThan(0));
      expect(field.distanceAt(0, 0), greaterThan(0));
    });

    test('bakes the hole of a composed bar-with-hole shape', () {
      const size = Size(300, 64);
      const holeCentre = Offset(150, 32);
      final hole = GlassShape.path(
        (s) => Path()..addOval(Rect.fromCircle(center: holeCentre, radius: 28)),
        sdfFn: (p, s) => ShapeSdf.circle(p - holeCentre, 28),
      );
      final shape = const GlassShape.roundedRect(20).difference(hole);
      final field = SdfField.sample(shape, size, resolution: 60);
      // The cell over the hole centre must read as outside (carved away).
      final cx = (holeCentre.dx / size.width * field.width).floor();
      final cy = (holeCentre.dy / size.height * field.height).floor();
      expect(field.distanceAt(cx, cy), greaterThan(0));
    });
  });

  group('encode / decode', () {
    test('round-trips distances within ±spread to byte precision', () {
      const shape = GlassShape.roundedRect(10);
      final field = SdfField.sample(shape, const Size(64, 64), resolution: 32, spread: 32);
      final bytes = field.toRgba8();
      // An interior-but-near-edge cell whose distance is within ±spread.
      const x = 4, y = 16;
      final raw = field.distanceAt(x, y).clamp(-field.spread, field.spread);
      final stored = bytes[(y * field.width + x) * 4];
      expect(field.decodeByte(stored), closeTo(raw, field.spread / 255 * 2));
    });

    test('the edge encodes to ~0.5 (mid-grey)', () {
      final field = SdfField.sample(
        const GlassShape.roundedRect(0),
        const Size(100, 100),
        resolution: 100,
        spread: 32,
      );
      // Top edge row, middle column: distance ~0 -> normalised ~0.5.
      expect(field.normalizedAt(50, 0), closeTo(0.5, 0.05));
    });
  });

  testWidgets('toImage produces an RGBA image of the grid size', (tester) async {
    final field = SdfField.sample(
      const GlassShape.circle(),
      const Size(120, 60),
      resolution: 48,
    );
    // Image decoding is an engine callback outside the test's fake-async zone,
    // so it must run via runAsync or its future never completes.
    final image = (await tester.runAsync(field.toImage))!;
    addTearDown(image.dispose);
    expect(image.width, field.width);
    expect(image.height, field.height);
  });
}
